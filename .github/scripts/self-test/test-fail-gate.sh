#!/usr/bin/env bash
# Unit tests for scripts/fail-gate.sh and pro/scripts/fail-gate.sh. The gate
# is the one place a regression silently turns a failing PR green (or the
# reverse), so every severity combination is pinned here.
 
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
free="$root/scripts/fail-gate.sh"
pro="$root/pro/scripts/fail-gate.sh"
failures=0
 
# gate <script> VAR=value ...: runs the gate with a clean, "everything
# fine" environment plus the given overrides; echoes its exit code.
gate() {
  local script="$1"
  shift
  env -i PATH="$PATH" \
    USINGS_COUNT=0 TOOL_ERROR=false BUILD_FAILED=false \
    LICENSED=true VULN_FAILED=false SCAN_ERROR=false SECRETS_COUNT=0 \
    "$@" bash "$script" > /dev/null 2>&1
  echo $?
}
 
expect() { # <description> <got> <want>
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected exit $3, got $2"
    failures=$((failures + 1))
  fi
}
 
# ---- Free gate -------------------------------------------------------
expect "free: clean" "$(gate "$free")" 0
expect "free: build failure always blocks" "$(gate "$free" BUILD_FAILED=true)" 1
expect "free: build failure blocks even with checks off" \
  "$(gate "$free" BUILD_FAILED=true USINGS_SEVERITY=off)" 1
expect "free: usings block by default" "$(gate "$free" USINGS_COUNT=3)" 1
expect "free: usings blocking explicit" \
  "$(gate "$free" USINGS_COUNT=3 USINGS_SEVERITY=blocking)" 1
expect "free: usings advisory don't fail" \
  "$(gate "$free" USINGS_COUNT=3 USINGS_SEVERITY=advisory)" 0
expect "free: usings off don't fail" \
  "$(gate "$free" USINGS_COUNT=3 USINGS_SEVERITY=off)" 0
expect "free: tool error blocks by default" "$(gate "$free" TOOL_ERROR=true)" 1
expect "free: tool error ignored when advisory" \
  "$(gate "$free" TOOL_ERROR=true USINGS_SEVERITY=advisory)" 0
expect "free: nullable advisory by default" \
  "$(gate "$free" NULLABLE_COUNT=5)" 0
expect "free: nullable blocking when configured" \
  "$(gate "$free" NULLABLE_COUNT=5 NULLABLE_SEVERITY=blocking)" 1
expect "free: nullable blocking but none found" \
  "$(gate "$free" NULLABLE_COUNT=0 NULLABLE_SEVERITY=blocking)" 0
expect "free: nullable blocking, count unset" \
  "$(gate "$free" NULLABLE_SEVERITY=blocking)" 0
 
# ---- Pro gate --------------------------------------------------------
expect "pro: clean" "$(gate "$pro")" 0
expect "pro: build failure blocks" "$(gate "$pro" BUILD_FAILED=true)" 1
expect "pro: usings block by default" "$(gate "$pro" USINGS_COUNT=2)" 1
expect "pro: usings advisory" \
  "$(gate "$pro" USINGS_COUNT=2 USINGS_SEVERITY=advisory)" 0
expect "pro: nullable blocking" \
  "$(gate "$pro" NULLABLE_COUNT=1 NULLABLE_SEVERITY=blocking)" 1
expect "pro: vuln below threshold blocks by default" \
  "$(gate "$pro" VULN_FAILED=true)" 1
expect "pro: vuln advisory" \
  "$(gate "$pro" VULN_FAILED=true VULNS_SEVERITY=advisory)" 0
expect "pro: vuln off" "$(gate "$pro" VULN_FAILED=true VULNS_SEVERITY=off)" 0
expect "pro: scan error blocks by default" "$(gate "$pro" SCAN_ERROR=true)" 1
expect "pro: scan error ignored when advisory" \
  "$(gate "$pro" SCAN_ERROR=true VULNS_SEVERITY=advisory)" 0
expect "pro: secrets block by default" "$(gate "$pro" SECRETS_COUNT=1)" 1
expect "pro: secrets advisory" \
  "$(gate "$pro" SECRETS_COUNT=1 SECRETS_SEVERITY=advisory)" 0
expect "pro: secrets off" \
  "$(gate "$pro" SECRETS_COUNT=1 SECRETS_SEVERITY=off)" 0
expect "pro: unlicensed skips pro checks" \
  "$(gate "$pro" LICENSED=false SECRETS_COUNT=9 VULN_FAILED=true)" 0
expect "pro: unlicensed still enforces free checks" \
  "$(gate "$pro" LICENSED=false USINGS_COUNT=1)" 1
 
# Baseline mode: NEW_* replace the raw counts.
expect "pro: baseline absorbs old usings" \
  "$(gate "$pro" USINGS_COUNT=7 NEW_USINGS=0)" 0
expect "pro: baseline flags new usings" \
  "$(gate "$pro" USINGS_COUNT=7 NEW_USINGS=2)" 1
expect "pro: baseline absorbs old secrets" \
  "$(gate "$pro" SECRETS_COUNT=3 NEW_SECRETS=0)" 0
expect "pro: baseline flags new secrets" \
  "$(gate "$pro" SECRETS_COUNT=3 NEW_SECRETS=1)" 1
expect "pro: baseline + advisory usings" \
  "$(gate "$pro" USINGS_COUNT=7 NEW_USINGS=2 USINGS_SEVERITY=advisory)" 0
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures fail-gate test(s) failed"
  exit 1
fi
echo "fail-gate tests passed"