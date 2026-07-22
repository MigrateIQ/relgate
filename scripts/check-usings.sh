#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH, CHANGED_ONLY, CHANGED_FILES
# Outputs: count, tool_error

path_args=()
if [ -n "$PROJECT_PATH" ]; then
  path_args=("$PROJECT_PATH")
fi

# changed-files-only with nothing changed means there's nothing for this
# check to look at - skip rather than falling back to a whole-repo scan
# that could fail the PR on unrelated debt.
if [ "$CHANGED_ONLY" = "true" ] && [ -z "$CHANGED_FILES" ]; then
  echo "No changed .cs files - skipping unused-usings check."
  echo "count=0" >> "$GITHUB_OUTPUT"
  echo "tool_error=false" >> "$GITHUB_OUTPUT"
  exit 0
fi

if [ "$CHANGED_ONLY" = "true" ]; then
  dotnet format style "${path_args[@]}" \
    --verify-no-changes --severity warn --diagnostics IDE0005 \
    --include $CHANGED_FILES > usings-output.txt 2>&1
else
  dotnet format style "${path_args[@]}" \
    --verify-no-changes --severity warn --diagnostics IDE0005 \
    > usings-output.txt 2>&1
fi
format_exit=$?
count=$(grep -c "IDE0005" usings-output.txt || true)
echo "count=$count" >> "$GITHUB_OUTPUT"

# Exit code 2 means "violations found" (expected, captured by the grep
# count above). Anything else non-zero means the tool itself failed to
# run (bad project, missing SDK, etc.) - don't let that get silently
# swallowed and reported as "clean".
if [ "$format_exit" -ne 0 ] && [ "$format_exit" -ne 2 ]; then
  echo "tool_error=true" >> "$GITHUB_OUTPUT"
else
  echo "tool_error=false" >> "$GITHUB_OUTPUT"
fi
