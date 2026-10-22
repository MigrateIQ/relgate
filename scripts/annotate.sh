#!/usr/bin/env bash
# Sourced by check-usings.sh and check-nullable-and-build.sh - not run
# directly.
#
# Turns MSBuild-style diagnostics ("path(line,col): warning CODE ...") into
# GitHub workflow commands, so findings show up inline on the PR diff and
# in the checks UI instead of only as a count in the comment.
#
# usage: emit_annotations <error|warning> <title> <pattern> <file>
#   <pattern> is an ERE matching "path(line,col): level CODE" in <file>.
#
# GitHub caps how many annotations it renders per step, so past
# MAX_ANNOTATIONS the rest are summarised in one notice (the PR comment
# still carries the full count).
MAX_ANNOTATIONS="${MAX_ANNOTATIONS:-10}"
 
# Workflow-command property values must escape %, CR, LF, ':' and ','.
annotate_escape() {
  local s="$1"
  s="${s//'%'/%25}"
  s="${s//$'\r'/%0D}"
  s="${s//$'\n'/%0A}"
  s="${s//':'/%3A}"
  s="${s//','/%2C}"
  printf '%s' "$s"
}
 
emit_annotations() {
  local level="$1" title="$2" pattern="$3" file="$4"
  local shown=0 total=0 diag path rest ln code
 
  [ -s "$file" ] || return 0
 
  while IFS= read -r diag; do
    [ -z "$diag" ] && continue
    total=$((total + 1))
    [ "$shown" -ge "$MAX_ANNOTATIONS" ] && continue
 
    path="${diag%%(*}"
    rest="${diag#*(}"
    ln="${rest%%,*}"
    code="${diag##* }"
    # Workflow commands want repo-relative paths.
    path="${path#"${GITHUB_WORKSPACE:-}"/}"
 
    echo "::$level file=$(annotate_escape "$path"),line=$ln,title=$(annotate_escape "$title")::$code"
    shown=$((shown + 1))
  done < <(grep -oE "$pattern" "$file" | tr -d '\r' | sort -u)
 
  if [ "$total" -gt "$shown" ]; then
    echo "::notice::RelGate: $((total - shown)) more $title finding(s) not annotated inline - see the PR comment for the full count."
  fi
}