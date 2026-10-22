#!/usr/bin/env bash
# Inputs (env): CHANGED_ONLY, CHANGED_FILES, SECRET_EXCLUDE (optional,
#               space- or comma-separated globs, e.g. "*.md,docs/*")
# Outputs: count
#
# Only file:line:pattern-type is ever recorded – the matched value itself
# is never printed, logged, or written anywhere. A line containing
# "relgate:ignore" is never reported (for known-safe placeholders).
 
# Path excludes from .relgate.yml (RELGATE_EXCLUDE). scripts/ sits next to
# pro/ in the repo, so this is the same release's copy.
# shellcheck source=../../scripts/exclude.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../scripts/exclude.sh"
 
if [ "$CHANGED_ONLY" = "true" ]; then
  mapfile -t targets < <(printf '%s\n' "$CHANGED_FILES" | sed '/^$/d')
else
  targets=(.)
fi
 
if [ "${#targets[@]}" -eq 0 ]; then
  echo "count=0" >> "$GITHUB_OUTPUT"
  exit 0
fi
 
exclude_args=(--exclude-dir=.git --exclude-dir=bin --exclude-dir=obj)
for glob in $(printf '%s' "$SECRET_EXCLUDE" | tr ',' ' '); do
  exclude_args+=("--exclude=$glob")
done
 
# Key/value assignments. The optional quote before the separator is what
# lets JSON ("password": "...") match as well as key=value and YAML forms.
cred_pattern='(password|pwd|secret|apikey|api_key|token)"?'
cred_pattern+='[[:space:]]*[:=][[:space:]]*'
cred_pattern+='"?[A-Za-z0-9_!@#$%^&*-]{6,}'
 
# scan <type> <pattern>: prints file:line:type for each match, skipping
# lines marked relgate:ignore. -I skips binary files.
scan() {
  grep -riHnIE "${exclude_args[@]}" -- "$2" "${targets[@]}" 2>/dev/null \
    | grep -v 'relgate:ignore' \
    | cut -d: -f1,2 | sed "s/\$/:$1/"
}
 
{
  scan credential-assignment "$cred_pattern"
  scan private-key-header \
    '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----'
  scan aws-access-key-id '(AKIA|ASIA)[0-9A-Z]{16}'
  scan github-token '(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{36}'
} | sort -u > secret-hits.txt
 
# Hits in files excluded by .relgate.yml are dropped before counting,
# annotating or reporting.
filter_excluded_hits secret-hits.txt
 
count=$(wc -l < secret-hits.txt | tr -d ' ')
 
# Inline PR annotations: file, line and pattern type only - never the
# matched value. Capped because GitHub only renders a limited number of
# annotations per step; the PR comment lists the rest.
shown=0
while IFS=: read -r hit_file hit_line hit_type; do
  [ -z "$hit_file" ] && continue
  [ "$shown" -ge 10 ] && break
  hit_file="${hit_file#./}"
  hit_file="${hit_file//'%'/%25}"
  hit_file="${hit_file//':'/%3A}"
  hit_file="${hit_file//','/%2C}"
  echo "::error file=$hit_file,line=$hit_line,title=Potential secret::$hit_type - add 'relgate:ignore' to the line if this is a false positive"
  shown=$((shown + 1))
done < secret-hits.txt
 
echo "count=$count" >> "$GITHUB_OUTPUT"