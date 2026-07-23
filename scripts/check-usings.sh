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

# IDE0005 (unused usings) is disabled by default in Roslyn – it only
# fires if a project's .editorconfig explicitly sets its severity, which
# most repos don't have configured. --severity/--diagnostics only filter
# already-enabled diagnostics; there's no dotnet format flag to force-
# enable a disabled one. So: temporarily merge an override into the
# workspace-root .editorconfig (creating one if none exists, or adding a
# fresh [*.cs] section after any existing content if one does – .editor-
# config uses last-value-wins per key, so this doesn't remove any of the
# repo's own settings), run the check, then restore exactly what was
# there before. Known limitation: a target repo with its own nested
# .editorconfig setting `root = true` between the workspace root and the
# files being checked would stop this override from being inherited.
editorconfig_path="$GITHUB_WORKSPACE/.editorconfig"
editorconfig_existed=false
editorconfig_backup_path="$(mktemp)"
if [ -f "$editorconfig_path" ]; then
  editorconfig_existed=true
  cp "$editorconfig_path" "$editorconfig_backup_path"
fi
{
  [ "$editorconfig_existed" = "true" ] && cat "$editorconfig_path"
  echo ""
  echo "[*.cs]"
  echo "dotnet_diagnostic.IDE0005.severity = warning"
} > "$editorconfig_path.relgate-tmp"
mv "$editorconfig_path.relgate-tmp" "$editorconfig_path"

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

if [ "$editorconfig_existed" = "true" ]; then
  mv "$editorconfig_backup_path" "$editorconfig_path"
else
  rm -f "$editorconfig_path" "$editorconfig_backup_path"
fi

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
