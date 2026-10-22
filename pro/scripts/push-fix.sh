#!/usr/bin/env bash
# Sourced by auto-fix-usings.sh and auto-remediate.sh - not run directly.
# Inputs (env): HEAD_REF
# Sets: commit_sha (on success)
#
# On pull_request events actions/checkout leaves HEAD on the *merge* commit
# (refs/pull/N/merge), not the PR branch tip. Committing there and pushing
# HEAD:$HEAD_REF would drag the base branch's changes into the PR. So the
# fix is captured as a patch, the tree is moved onto the real PR head, and
# the patch is applied and committed there.
#
# usage: push_fix "<commit message>" <file>...
# Returns non-zero (nothing pushed) if the fix can't be applied or pushed.
push_fix() {
  local message="$1"
  shift
 
  local patch head_sha
  patch="$(mktemp)"
  git diff -- "$@" > "$patch"
 
  if ! git fetch --quiet --depth=1 origin "$HEAD_REF" 2>/dev/null; then
    echo "::warning::RelGate Pro: could not fetch '$HEAD_REF' from origin."
    rm -f "$patch"
    return 1
  fi
  head_sha=$(git rev-parse FETCH_HEAD)
 
  if [ "$(git rev-parse HEAD)" != "$head_sha" ]; then
    git checkout --quiet -- .
    git checkout --quiet --detach "$head_sha"
    if ! git apply --index "$patch" 2>/dev/null; then
      echo "::warning::RelGate Pro: fix no longer applies cleanly to the PR head (the base branch changed the same lines) - nothing was pushed."
      rm -f "$patch"
      return 1
    fi
  fi
  rm -f "$patch"
 
  git config user.name "github-actions[bot]"
  git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git add -- "$@"
  git commit -m "$message" >/dev/null 2>&1
 
  if git push origin "HEAD:$HEAD_REF" 2>/dev/null; then
    # shellcheck disable=SC2034  # read by the sourcing script's emit()
    commit_sha=$(git rev-parse --short HEAD)
    return 0
  fi
  echo "::warning::RelGate Pro: fix committed locally but the push failed (branch protection or a concurrent update?) - see logs."
  return 1
}