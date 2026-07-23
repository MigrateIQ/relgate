#!/usr/bin/env bash
# Inputs (env): LICENSE_API_URL, LICENSE_KEY
# Outputs: licensed

response=$(curl -sf --max-time 10 -X POST \
  "$LICENSE_API_URL/v1/licenses/validate" \
  -d "license_key=$LICENSE_KEY" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "License API unreachable – treating as unlicensed for this run."
  echo "licensed=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

valid=$(echo "$response" | jq -r '.valid // false')
product_id=$(echo "$response" | jq -r '.meta.product_id // empty')

# 1241016 is RelGate Pro's real Lemon Squeezy product ID (also used by the
# self-test mock server, so self-test validate against the same value production does).
if [ "$valid" = "true" ] && [ "$product_id" = "1241016" ]; then
  echo "licensed=true" >> "$GITHUB_OUTPUT"
else
  echo "licensed=false" >> "$GITHUB_OUTPUT"
fi
