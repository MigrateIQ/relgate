#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH, CHANGED_ONLY, CHANGED_FILES
# Outputs: count, build_failed

path_args=()
if [ -n "$PROJECT_PATH" ]; then
  path_args=("$PROJECT_PATH")
fi

dotnet build "${path_args[@]}" --no-restore \
  /p:TreatWarningsAsErrors=false > build-output.txt 2>&1
build_exit=$?

# Build health is always checked in full - an unrelated compile error
# still blocks a release. The nullable-warning *count* is scoped to
# changed files when changed-files-only is on, so pre-existing debt
# doesn't show up as new advisory noise.
#
# dotnet build's terminal logger prints each warning line twice (once
# live, once in the end-of-build recap) - dedupe by the file(line,col)
# diagnostic identifier so the count reflects distinct warnings, not
# raw matching lines.
diagnostic_pattern='[^ ]+\([0-9]+,[0-9]+\): warning CS8[0-9]{3}'
if [ "$CHANGED_ONLY" = "true" ] && [ -n "$CHANGED_FILES" ]; then
  printf '%s\n' $CHANGED_FILES > changed-files.txt
  count=$(grep -F -f changed-files.txt build-output.txt \
    | grep -oE "$diagnostic_pattern" | sort -u | wc -l)
else
  count=$(grep -oE "$diagnostic_pattern" build-output.txt | sort -u | wc -l)
fi
echo "count=$count" >> "$GITHUB_OUTPUT"

if [ "$build_exit" -ne 0 ]; then
  echo "build_failed=true" >> "$GITHUB_OUTPUT"
else
  echo "build_failed=false" >> "$GITHUB_OUTPUT"
fi
