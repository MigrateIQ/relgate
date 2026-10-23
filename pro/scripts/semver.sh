#!/usr/bin/env bash
# Sourced by auto-remediate.sh - not run directly.
#
# NuGet/SemVer version comparison in pure bash. `sort -V` is wrong for
# prerelease versions (it ranks 1.0.0-beta above 1.0.0), and which patched
# version gets picked decides what gets pushed to a PR branch.
#
#   semver_cmp A B   prints -1, 0 or 1
#   semver_max A B   prints the higher of the two
# Build metadata (+...) is ignored; up to four numeric core parts are
# compared (NuGet allows 1.2.3.4).
 
semver_cmp() {
  local a="${1%%+*}" b="${2%%+*}"
  local a_core="${a%%-*}" b_core="${b%%-*}"
  local a_pre="" b_pre=""
  [ "$a" != "$a_core" ] && a_pre="${a#*-}"
  [ "$b" != "$b_core" ] && b_pre="${b#*-}"
 
  local -a ap bp
  IFS=. read -ra ap <<< "$a_core"
  IFS=. read -ra bp <<< "$b_core"
  local i x y
  for i in 0 1 2 3; do
    x="${ap[$i]:-0}"
    y="${bp[$i]:-0}"
    if [ "$((10#$x))" -gt "$((10#$y))" ]; then echo 1; return; fi
    if [ "$((10#$x))" -lt "$((10#$y))" ]; then echo -1; return; fi
  done
 
  # Equal cores: a release outranks any of its prereleases.
  if [ -z "$a_pre" ] && [ -z "$b_pre" ]; then echo 0; return; fi
  if [ -z "$a_pre" ]; then echo 1; return; fi
  if [ -z "$b_pre" ]; then echo -1; return; fi
 
  # Both prereleases: compare dot-separated identifiers left to right.
  # Numeric < alphanumeric; numerics compare as numbers, the rest as text;
  # when all shared identifiers tie, the one with more identifiers wins.
  local -a ai bi
  IFS=. read -ra ai <<< "$a_pre"
  IFS=. read -ra bi <<< "$b_pre"
  local n="${#ai[@]}"
  [ "${#bi[@]}" -lt "$n" ] && n="${#bi[@]}"
  local k
  for ((k = 0; k < n; k++)); do
    x="${ai[$k]}"
    y="${bi[$k]}"
    if [ "$x" = "$y" ]; then continue; fi
    local x_num=false y_num=false
    [[ "$x" =~ ^[0-9]+$ ]] && x_num=true
    [[ "$y" =~ ^[0-9]+$ ]] && y_num=true
    if [ "$x_num" = true ] && [ "$y_num" = true ]; then
      if [ "$((10#$x))" -gt "$((10#$y))" ]; then echo 1; else echo -1; fi
    elif [ "$x_num" = true ]; then
      echo -1
    elif [ "$y_num" = true ]; then
      echo 1
    elif [[ "$x" > "$y" ]]; then
      echo 1
    else
      echo -1
    fi
    return
  done
  if [ "${#ai[@]}" -gt "${#bi[@]}" ]; then echo 1
  elif [ "${#ai[@]}" -lt "${#bi[@]}" ]; then echo -1
  else echo 0
  fi
}
 
semver_max() {
  if [ "$(semver_cmp "$1" "$2")" -ge 0 ]; then echo "$1"; else echo "$2"; fi
}
 
# Range matching - evaluates `vulnerable_version_range` strings like
# ">= 4.0.0, < 4.5.1" against the currently resolved version. Not `sort -V`:
# it ranks 1.0.0-beta above 1.0.0.
vercmp_ge() { [ "$(semver_cmp "$1" "$2")" -ge 0 ]; }
vercmp_gt() { [ "$(semver_cmp "$1" "$2")" -gt 0 ]; }
vercmp_le() { [ "$(semver_cmp "$1" "$2")" -le 0 ]; }
vercmp_lt() { [ "$(semver_cmp "$1" "$2")" -lt 0 ]; }
 
version_satisfies() {
  local ver="$1" range="$2" ok=true constraint op cver parts
  IFS=',' read -ra parts <<< "$range"
  for constraint in "${parts[@]}"; do
    constraint=$(printf '%s' "$constraint" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    op=$(printf '%s' "$constraint" | grep -oE '^(>=|<=|>|<|=)')
    cver=$(printf '%s' "$constraint" | sed -E 's/^(>=|<=|>|<|=)[[:space:]]*//')
    case "$op" in
      ">=") vercmp_ge "$ver" "$cver" || ok=false ;;
      ">")  vercmp_gt "$ver" "$cver" || ok=false ;;
      "<=") vercmp_le "$ver" "$cver" || ok=false ;;
      "<")  vercmp_lt "$ver" "$cver" || ok=false ;;
      "=")  [ "$(semver_cmp "$ver" "$cver")" -eq 0 ] || ok=false ;;
      *) ok=false ;;
    esac
  done
  [ "$ok" = "true" ]
}