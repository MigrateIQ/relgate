#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH, CHANGED_ONLY, CHANGED_FILES, USINGS_COUNT,
#               HEAD_REF, IS_FORK
# Outputs: fixed_count, outcome, commit_sha
#
# Applies the exact fix the free-tier check already told the developer to
# run locally (dotnet format style --diagnostics IDE0005) and pushes it,
# instead of only reporting the count. Reuses the same git-safety pattern
# already proven in auto-remediate.sh: explicit ref push, explicit
# staging, fork-skip, build-verify-or-abort.

commit_sha=""

emit() {
  echo "fixed_count=$1" >> "$GITHUB_OUTPUT"
  echo "outcome=$2" >> "$GITHUB_OUTPUT"
  echo "commit_sha=$commit_sha" >> "$GITHUB_OUTPUT"
}

if [ "$IS_FORK" = "true" ]; then
  echo "::notice::RelGate Pro: auto-fix-usings skipped - fork PRs can't receive pushed fixes."
  emit 0 "fork"
  exit 0
fi

# Idempotent fast exit: the free tier already computed this count, no
# need to re-run dotnet format just to find out there's nothing to do.
if [ "$USINGS_COUNT" = "0" ] || [ -z "$USINGS_COUNT" ]; then
  emit 0 "no-issues"
  exit 0
fi

path_args=()
if [ -n "$PROJECT_PATH" ]; then
  path_args=("$PROJECT_PATH")
fi

# Same override as scripts/check-usings.sh - IDE0005 is disabled by
# default in Roslyn, so it must be force-enabled via .editorconfig before
# dotnet format will touch it at all. Backed up and restored exactly the
# same way.
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

# No --verify-no-changes this time - actually rewrite the files. Scoped
# to the same CHANGED_FILES the free-tier check used, so this only fixes
# what was actually flagged, not unrelated repo-wide debt.
if [ "$CHANGED_ONLY" = "true" ]; then
  dotnet format style "${path_args[@]}" \
    --severity warn --diagnostics IDE0005 \
    --include $CHANGED_FILES >/dev/null 2>&1
else
  dotnet format style "${path_args[@]}" \
    --severity warn --diagnostics IDE0005 >/dev/null 2>&1
fi

if [ "$editorconfig_existed" = "true" ]; then
  mv "$editorconfig_backup_path" "$editorconfig_path"
else
  rm -f "$editorconfig_path" "$editorconfig_backup_path"
fi

# Excludes obj/bin explicitly rather than trusting the target repo's
# .gitignore - a tracked, regenerated file like obj/**/AssemblyInfo.cs
# changes on every build (it embeds the current git SHA) and would
# otherwise get swept into the fix commit as a false positive.
mapfile -t changed_files < <(git diff --name-only -- \
  '*.cs' ':(exclude,glob)**/obj/**' ':(exclude,glob)**/bin/**')
if [ "${#changed_files[@]}" -eq 0 ]; then
  echo "::notice::RelGate Pro: auto-fix-usings ran but produced no file changes - leaving as-is."
  emit 0 "no-changes"
  exit 0
fi

if ! dotnet build "${path_args[@]}" >/dev/null 2>&1; then
  echo "::warning::RelGate Pro: auto-fix-usings would break the build - discarding the fix, no commit was made."
  git checkout -- . 2>/dev/null
  emit 0 "build-failed"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -- "${changed_files[@]}"
git commit -m "chore(relgate): remove unused usings" >/dev/null 2>&1

if git push origin "HEAD:$HEAD_REF" 2>/dev/null; then
  commit_sha=$(git rev-parse --short HEAD)
  emit "${#changed_files[@]}" "ok"
else
  echo "::warning::RelGate Pro: fix committed locally but the push failed (branch protection or a concurrent update?) - see logs."
  emit 0 "push-failed"
fi
