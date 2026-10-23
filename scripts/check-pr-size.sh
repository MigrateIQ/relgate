#!/usr/bin/env bash
# Inputs (env): CHANGED_FILES, PR_SIZE_THRESHOLD
# Outputs: count
#
# Advisory only - a large PR isn't objectively wrong, just worth a human's
# attention, so this never contributes to the blocking/fail decision.
 
count=0
if [ -n "$CHANGED_FILES" ]; then
  count=$(printf '%s\n' "$CHANGED_FILES" | grep -c .)
fi
 
echo "count=$count" >> "$GITHUB_OUTPUT"