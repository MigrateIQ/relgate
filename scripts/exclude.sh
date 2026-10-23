#!/usr/bin/env bash
# Sourced by check-usings.sh, check-nullable-and-build.sh and (Pro)
# secret-scan.sh - not run directly.
#
# Path excludes from .relgate.yml. RELGATE_EXCLUDE holds the globs,
# newline-separated. Matching is bash glob matching where * also crosses
# '/', so "*.g.cs" matches at any depth and "**/Migrations/**" works.
# Each path is tried as given and with a leading '/', so "**/Migrations/**"
# also matches a top-level "Migrations/x.cs". A trailing '/' means "this
# directory and everything under it".
#
#   path_excluded <repo-relative path>        0 if excluded
#   filter_excluded_diagnostics <file>        drop "path(line,col): ..."
#                                             lines whose path is excluded
#   filter_excluded_hits <file>               drop "path:line:type" lines
#                                             whose path is excluded
 
path_excluded() {
  local path="${1#./}" glob
  [ -n "${RELGATE_EXCLUDE:-}" ] || return 1
  while IFS= read -r glob; do
    [ -z "$glob" ] && continue
    glob="${glob#./}"
    case "$glob" in */) glob="${glob}*" ;; esac
    # shellcheck disable=SC2053  # the right-hand side is meant as a glob
    if [[ "$path" == $glob || "/$path" == $glob ]]; then
      return 0
    fi
  done <<< "$RELGATE_EXCLUDE"
  return 1
}
 
filter_excluded_diagnostics() {
  local file="$1" tmp line path
  [ -n "${RELGATE_EXCLUDE:-}" ] && [ -s "$file" ] || return 0
  tmp=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ([^[:space:]]+)\([0-9]+,[0-9]+\):[[:space:]] ]]; then
      path="${BASH_REMATCH[1]#"${GITHUB_WORKSPACE:-}"/}"
      path_excluded "$path" && continue
    fi
    printf '%s\n' "$line"
  done < "$file" > "$tmp"
  mv "$tmp" "$file"
}
 
filter_excluded_hits() {
  local file="$1" tmp line
  [ -n "${RELGATE_EXCLUDE:-}" ] && [ -s "$file" ] || return 0
  tmp=$(mktemp)
  while IFS= read -r line || [ -n "$line" ]; do
    path_excluded "${line%%:*}" && continue
    printf '%s\n' "$line"
  done < "$file" > "$tmp"
  mv "$tmp" "$file"
}