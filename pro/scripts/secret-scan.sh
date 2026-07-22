#!/usr/bin/env bash
# Inputs (env): CHANGED_ONLY, CHANGED_FILES
# Outputs: count
#
# Only file:line:pattern-type is ever recorded – the matched value itself
# is never printed, logged, or written anywhere.

if [ "$CHANGED_ONLY" = "true" ]; then
  targets="$CHANGED_FILES"
else
  targets="."
fi

if [ -z "$targets" ]; then
  echo "count=0" >> "$GITHUB_OUTPUT"
  exit 0
fi

exclude_args=(--exclude-dir=.git --exclude-dir=bin --exclude-dir=obj)
cred_pattern='(password|pwd|secret|apikey|api_key|token)'
cred_pattern+='[[:space:]]*[:=][[:space:]]*'
cred_pattern+='"?[A-Za-z0-9_!@#$%^&*-]{6,}'

{
  grep -riHnE "${exclude_args[@]}" \
    -- "$cred_pattern" $targets 2>/dev/null \
    | cut -d: -f1,2 | sed 's/$/:credential-assignment/'
  grep -riHnE "${exclude_args[@]}" \
    -- '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----' \
    $targets 2>/dev/null \
    | cut -d: -f1,2 | sed 's/$/:private-key-header/'
} | sort -u > secret-hits.txt

count=$(wc -l < secret-hits.txt | tr -d ' ')
echo "count=$count" >> "$GITHUB_OUTPUT"
