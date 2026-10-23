#!/usr/bin/env bash
# Inputs (env): SARIF_PATH
# The pro-licensed job runs the vulnerable + secrets fixtures, so the SARIF
# must contain both vulnerability (RG004) and secret (RG003) results.
 
if [ -z "$SARIF_PATH" ] || [ ! -s "$SARIF_PATH" ]; then
  echo "::error::expected a generated SARIF file, got '$SARIF_PATH'"
  exit 1
fi
 
for rule in RG003 RG004; do
  n=$(jq "[.runs[0].results[] | select(.ruleId == \"$rule\")] | length" "$SARIF_PATH")
  if [ "$n" -eq 0 ]; then
    echo "::error::expected SARIF results for $rule, found none"
    exit 1
  fi
done