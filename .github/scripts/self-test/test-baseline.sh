#!/usr/bin/env bash
# Unit tests for pro/scripts/baseline.sh - no dotnet or network.
 
# Git Bash on Windows rewrites "/ws/"-style arguments into Windows paths;
# no effect on Linux runners.
export MSYS_NO_PATHCONV=1
 
script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../pro/scripts" && pwd)/baseline.sh"
failures=0
 
expect_eq() {
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected '$3', got '$2'"
    failures=$((failures + 1))
  fi
}
 
work="$(mktemp -d)"
cd "$work" || exit 1
export GITHUB_WORKSPACE=/ws GITHUB_OUTPUT="$work/out.txt"
baseline=".relgate/baseline.json"
 
out() { grep "^$1=" "$GITHUB_OUTPUT" | tail -1 | cut -d= -f2-; }
run() { : > "$GITHUB_OUTPUT"; MODE="$1" BASELINE_FILE="$baseline" bash "$script" > "$work/log.txt" 2>&1; }
 
# Today's findings: A.cs has 2 unused usings, B.cs has 1; one secret.
printf '%s\n' \
  '/ws/src/A.cs(1,1): warning IDE0005: unnecessary [/ws/p.csproj]' \
  '/ws/src/A.cs(2,1): warning IDE0005: unnecessary [/ws/p.csproj]' \
  '/ws/src/B.cs(5,1): warning IDE0005: unnecessary [/ws/p.csproj]' \
  > usings-output.txt
printf '%s\n' './config/app.json:4:credential-assignment' > secret-hits.txt
 
# --- write mode captures the current state and never counts it as new.
run write
expect_eq "write: file created" "$(test -s $baseline && echo yes)" "yes"
expect_eq "write: usings A" "$(jq -r '.usings["src/A.cs"]' $baseline)" "2"
expect_eq "write: usings B" "$(jq -r '.usings["src/B.cs"]' $baseline)" "1"
expect_eq "write: secret key" \
  "$(jq -r '.secrets["config/app.json|credential-assignment"]' $baseline)" "1"
expect_eq "write: new usings is 0" "$(out new_usings)" "0"
expect_eq "write: new secrets is 0" "$(out new_secrets)" "0"
expect_eq "write: written path" "$(out written)" "$baseline"
# Nothing sensitive: no line numbers, no source text, only counts.
expect_eq "write: no line numbers stored" \
  "$(grep -c '(1,1)\|:4:' $baseline)" "0"
 
# --- unchanged findings: all baselined, none new.
run apply
expect_eq "same: new usings" "$(out new_usings)" "0"
expect_eq "same: baselined usings" "$(out baselined_usings)" "3"
expect_eq "same: new secrets" "$(out new_secrets)" "0"
expect_eq "same: baselined secrets" "$(out baselined_secrets)" "1"
 
# --- the same findings on different lines (code moved) are still baselined.
printf '%s\n' \
  '/ws/src/A.cs(40,1): warning IDE0005: unnecessary' \
  '/ws/src/A.cs(41,1): warning IDE0005: unnecessary' \
  '/ws/src/B.cs(90,1): warning IDE0005: unnecessary' \
  > usings-output.txt
printf '%s\n' './config/app.json:77:credential-assignment' > secret-hits.txt
run apply
expect_eq "shifted: new usings" "$(out new_usings)" "0"
expect_eq "shifted: new secrets" "$(out new_secrets)" "0"
 
# --- an extra using in a known file, and a using in a brand-new file.
printf '%s\n' \
  '/ws/src/A.cs(1,1): warning IDE0005' \
  '/ws/src/A.cs(2,1): warning IDE0005' \
  '/ws/src/A.cs(3,1): warning IDE0005' \
  '/ws/src/B.cs(5,1): warning IDE0005' \
  '/ws/src/New.cs(1,1): warning IDE0005' \
  > usings-output.txt
run apply
expect_eq "regression: new usings" "$(out new_usings)" "2"
expect_eq "regression: baselined usings" "$(out baselined_usings)" "3"
 
# --- a new secret type in a known file is new; a known one stays baselined.
printf '%s\n' \
  './config/app.json:4:credential-assignment' \
  './config/app.json:9:aws-access-key-id' \
  > secret-hits.txt
run apply
expect_eq "secrets: new" "$(out new_secrets)" "1"
expect_eq "secrets: baselined" "$(out baselined_secrets)" "1"
 
# --- fewer findings than the baseline (improvement) never goes negative.
printf '%s\n' '/ws/src/A.cs(1,1): warning IDE0005' > usings-output.txt
: > secret-hits.txt
run apply
expect_eq "improved: new usings" "$(out new_usings)" "0"
expect_eq "improved: baselined usings" "$(out baselined_usings)" "1"
 
# --- missing or corrupt baseline: everything is new, with a warning.
printf '%s\n' \
  '/ws/src/A.cs(1,1): warning IDE0005' \
  '/ws/src/A.cs(2,1): warning IDE0005' > usings-output.txt
mv $baseline "$baseline.bak"
run apply
expect_eq "missing: new usings" "$(out new_usings)" "2"
expect_eq "missing: warned" "$(grep -c '::warning::' "$work/log.txt")" "1"
echo 'not json' > $baseline
run apply
expect_eq "corrupt: new usings" "$(out new_usings)" "2"
expect_eq "corrupt: warned" "$(grep -c '::warning::' "$work/log.txt")" "1"
 
# --- no findings at all.
: > usings-output.txt
mv "$baseline.bak" $baseline
run apply
expect_eq "empty: new usings" "$(out new_usings)" "0"
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures baseline test(s) failed"
  exit 1
fi
echo "baseline tests passed"