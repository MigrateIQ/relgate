#!/usr/bin/env bash
# Inputs (env): MODE (apply|write), BASELINE_FILE, GITHUB_WORKSPACE
# Reads (whatever earlier steps left in the workspace):
#   usings-output.txt, secret-hits.txt
# Outputs: new_usings, new_secrets, baselined_usings, baselined_secrets,
#          written (write mode only: the baseline file path)
#
# Baseline / ratchet mode: accept the findings that exist today and fail
# only on new ones, so a legacy codebase can adopt RelGate without first
# fixing every old finding.
#
# The baseline stores COUNTS, not line numbers or line content:
#   {"version":1,
#    "usings":  {"src/A.cs": 2},
#    "secrets": {"config/app.json|credential-assignment": 1}}
# Line numbers shift with every edit, and a hash of a secret-bearing line
# would put secret-derived data in the repo - counts per file (and per
# file+type for secrets) are stable and contain nothing sensitive. A
# finding is "new" when a file's current count exceeds its baselined
# count. Known limitation: fixing one finding and adding another in the
# same file nets to zero.
#
# Vulnerable packages are intentionally not baselined - the readiness
# score already has its own configurable threshold.
 
workspace="${GITHUB_WORKSPACE:-}/"
 
# file -> count of unused usings, as a JSON object.
current_usings() {
  if [ ! -s usings-output.txt ]; then echo '{}'; return; fi
  grep -oE '[^ ]+\([0-9]+,[0-9]+\): (warning|error) IDE0005' \
    usings-output.txt | tr -d '\r' | sort -u \
    | jq -R -s --arg ws "$workspace" '
        split("\n") | map(select(length > 0)) |
        map(sub("\\([0-9]+,[0-9]+\\).*$"; "") | ltrimstr($ws)) |
        group_by(.) | map({key: .[0], value: length}) | from_entries'
}
 
# "file|type" -> count of secret hits, as a JSON object. secret-hits.txt
# lines are file:line:type; only file and type are kept.
current_secrets() {
  if [ ! -s secret-hits.txt ]; then echo '{}'; return; fi
  jq -R -s '
    split("\n") | map(select(length > 0)) |
    map(split(":") | ((.[0] | ltrimstr("./")) + "|" + .[2])) |
    group_by(.) | map({key: .[0], value: length}) | from_entries' \
    secret-hits.txt
}
 
# new_count <current-json> <baseline-json>: sum of per-key excess over
# the baseline.
new_count() {
  jq -n --argjson cur "$1" --argjson base "$2" '
    [$cur | to_entries[] |
     (.value - ($base[.key] // 0)) | if . < 0 then 0 else . end] |
    add // 0'
}
 
total_count() {
  jq -n --argjson cur "$1" '[$cur[]] | add // 0'
}
 
usings=$(current_usings)
secrets=$(current_secrets)
 
if [ "$MODE" = "write" ]; then
  mkdir -p "$(dirname "$BASELINE_FILE")"
  jq -n --argjson usings "$usings" --argjson secrets "$secrets" \
    '{version: 1, usings: $usings, secrets: $secrets}' > "$BASELINE_FILE"
  echo "::notice::RelGate: baseline written to $BASELINE_FILE ($(total_count "$usings") unused usings, $(total_count "$secrets") secret hits). Commit it, then enable baseline-file on pull requests."
  # Capturing the current state is the point of this run - nothing in it
  # counts as new, so the gate doesn't fail while writing.
  {
    echo "new_usings=0"
    echo "new_secrets=0"
    echo "baselined_usings=$(total_count "$usings")"
    echo "baselined_secrets=$(total_count "$secrets")"
    echo "written=$BASELINE_FILE"
  } >> "$GITHUB_OUTPUT"
  exit 0
fi
 
base_usings='{}'
base_secrets='{}'
if [ -s "$BASELINE_FILE" ] && jq -e . "$BASELINE_FILE" >/dev/null 2>&1; then
  base_usings=$(jq -c '.usings // {}' "$BASELINE_FILE")
  base_secrets=$(jq -c '.secrets // {}' "$BASELINE_FILE")
else
  echo "::warning::RelGate Pro: baseline file '$BASELINE_FILE' not found or not valid JSON - treating every finding as new."
fi
 
new_usings=$(new_count "$usings" "$base_usings")
new_secrets=$(new_count "$secrets" "$base_secrets")
total_usings=$(total_count "$usings")
total_secrets=$(total_count "$secrets")
 
{
  echo "new_usings=$new_usings"
  echo "new_secrets=$new_secrets"
  echo "baselined_usings=$((total_usings - new_usings))"
  echo "baselined_secrets=$((total_secrets - new_secrets))"
} >> "$GITHUB_OUTPUT"