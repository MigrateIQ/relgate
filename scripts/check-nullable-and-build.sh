#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH, CHANGED_ONLY, CHANGED_FILES
# Outputs: count, build_failed
 
# Optional env, from .relgate.yml: NULLABLE_SEVERITY (blocking|advisory|off,
# default advisory), RELGATE_EXCLUDE (newline-separated globs). 'off' only
# skips the nullable-warning count - build health is always checked.
 
# shellcheck source=annotate.sh
. "$(dirname "${BASH_SOURCE[0]}")/annotate.sh"
# shellcheck source=exclude.sh
. "$(dirname "${BASH_SOURCE[0]}")/exclude.sh"
 
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
  printf '%s\n' "$CHANGED_FILES" | sed '/^$/d' > changed-files.txt
  grep -F -f changed-files.txt build-output.txt \
    | grep -oE "$diagnostic_pattern" | sort -u > nullable-diagnostics.txt
else
  grep -oE "$diagnostic_pattern" build-output.txt \
    | sort -u > nullable-diagnostics.txt
fi
if [ "${NULLABLE_SEVERITY:-advisory}" = "off" ]; then
  : > nullable-diagnostics.txt
fi
 
# Findings in files excluded by .relgate.yml don't count (or annotate).
filter_excluded_diagnostics nullable-diagnostics.txt
 
count=$(wc -l < nullable-diagnostics.txt | tr -d ' ')
 
# Shown inline on the PR diff: warnings while advisory, errors if the
# config makes nullable warnings blocking.
annotation_level=warning
[ "${NULLABLE_SEVERITY:-advisory}" = "blocking" ] && annotation_level=error
emit_annotations "$annotation_level" "Nullable warning" "$diagnostic_pattern" \
  nullable-diagnostics.txt
 
echo "count=$count" >> "$GITHUB_OUTPUT"
 
if [ "$build_exit" -ne 0 ]; then
  echo "build_failed=true" >> "$GITHUB_OUTPUT"
else
  echo "build_failed=false" >> "$GITHUB_OUTPUT"
fi