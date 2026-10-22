#!/usr/bin/env bash
# Unit tests for pro/scripts/semver.sh - no dotnet or network needed.
 
# shellcheck source=../../../pro/scripts/semver.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../pro/scripts/semver.sh"
 
failures=0
 
expect_cmp() {
  local got
  got=$(semver_cmp "$1" "$2")
  if [ "$got" != "$3" ]; then
    echo "::error::semver_cmp $1 $2: expected $3, got $got"
    failures=$((failures + 1))
  fi
}
 
expect_max() {
  local got
  got=$(semver_max "$1" "$2")
  if [ "$got" != "$3" ]; then
    echo "::error::semver_max $1 $2: expected $3, got $got"
    failures=$((failures + 1))
  fi
}
 
expect_cmp 1.0.0 1.0.0 0
expect_cmp 1.0.1 1.0.0 1
expect_cmp 1.0.0 1.0.1 -1
expect_cmp 10.0.0 9.9.9 1
expect_cmp 1.2 1.2.0 0
expect_cmp 1.2.3.4 1.2.3.5 -1
expect_cmp 1.0.0+build5 1.0.0 0
expect_cmp 01.02.03 1.2.3 0
 
# The case `sort -V` gets wrong: a release outranks its prereleases.
expect_cmp 1.0.0 1.0.0-beta 1
expect_cmp 1.0.0-beta 1.0.0 -1
expect_cmp 1.0.0-alpha 1.0.0-beta -1
expect_cmp 1.0.0-beta.2 1.0.0-beta.11 -1
expect_cmp 1.0.0-beta 1.0.0-beta.1 -1
expect_cmp 1.0.0-1 1.0.0-alpha -1
expect_cmp 1.0.0-rc.1 1.0.0-rc.1 0
expect_cmp 2.0.0-beta 1.9.9 1
 
expect_max 4.5.1 4.5.0 4.5.1
expect_max 4.5.0 4.5.1 4.5.1
expect_max 1.0.0-beta 1.0.0 1.0.0
expect_max 13.0.1 9.0.1 13.0.1
 
expect_in_range() {
  if version_satisfies "$1" "$2"; then got=true; else got=false; fi
  if [ "$got" != "$3" ]; then
    echo "::error::version_satisfies $1 '$2': expected $3, got $got"
    failures=$((failures + 1))
  fi
}
 
# GHSA-style vulnerable_version_range strings.
expect_in_range 4.5.0 ">= 4.0.0, < 4.5.1" true
expect_in_range 4.5.1 ">= 4.0.0, < 4.5.1" false
expect_in_range 3.9.9 ">= 4.0.0, < 4.5.1" false
expect_in_range 9.0.1 "< 13.0.1" true
expect_in_range 13.0.1 "< 13.0.1" false
expect_in_range 1.2.0 "= 1.2" true
expect_in_range 1.0.0-beta "< 1.0.0" true
expect_in_range 1.0.0 "<= 1.0.0" true
expect_in_range 2.0.0 "garbage" false
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures semver test(s) failed"
  exit 1
fi
echo "semver tests passed"