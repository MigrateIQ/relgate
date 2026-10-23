#!/usr/bin/env bash
# Unit tests for scripts/exclude.sh - no dotnet, yq or jq needed.
 
# shellcheck source=../../../scripts/exclude.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts" && pwd)/exclude.sh"
 
failures=0
export GITHUB_WORKSPACE=/ws
 
expect_excluded() {
  if path_excluded "$1"; then got=excluded; else got=kept; fi
  if [ "$got" != "$2" ]; then
    echo "::error::path_excluded '$1': expected $2, got $got"
    failures=$((failures + 1))
  fi
}
 
expect_eq() {
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected '$3', got '$2'"
    failures=$((failures + 1))
  fi
}
 
RELGATE_EXCLUDE=$'**/Migrations/**\n*.Designer.cs\nsrc/Generated/\n./legacy/*'
export RELGATE_EXCLUDE
 
expect_excluded src/Data/Migrations/001_Init.cs excluded
expect_excluded Migrations/001_Init.cs excluded
expect_excluded ./Migrations/001_Init.cs excluded
expect_excluded src/Forms/Main.Designer.cs excluded
expect_excluded Main.Designer.cs excluded
expect_excluded src/Generated/Api/Client.cs excluded
expect_excluded legacy/Old.cs excluded
expect_excluded src/Data/Repo.cs kept
expect_excluded src/Generated.cs kept
expect_excluded src/MigrationsHelper.cs kept
expect_excluded src/Main.cs kept
 
# No excludes configured: nothing is excluded, filters are no-ops.
RELGATE_EXCLUDE=""
expect_excluded src/Data/Migrations/001_Init.cs kept
 
work="$(mktemp -d)"
cd "$work" || exit 1
 
# --- diagnostics filter: excluded paths dropped, other lines untouched.
RELGATE_EXCLUDE=$'**/Migrations/**\n*.Designer.cs'
cat > diags.txt <<'EOF'
Restore complete.
/ws/src/A.cs(3,1): warning IDE0005: Using directive is unnecessary.
/ws/src/Data/Migrations/M1.cs(1,1): warning IDE0005: Using directive is unnecessary.
/ws/src/F.Designer.cs(9,2): warning IDE0005: Using directive is unnecessary.
Format complete.
EOF
filter_excluded_diagnostics diags.txt
expect_eq "diagnostics kept" "$(grep -c 'src/A.cs' diags.txt)" "1"
expect_eq "migrations dropped" "$(grep -c 'Migrations' diags.txt)" "0"
expect_eq "designer dropped" "$(grep -c 'Designer' diags.txt)" "0"
expect_eq "non-diagnostic lines kept" "$(grep -c 'complete' diags.txt)" "2"
 
# --- hits filter (file:line:type).
printf '%s\n' \
  './src/Data/Migrations/seed.json:4:credential-assignment' \
  './src/app.json:7:credential-assignment' > hits.txt
filter_excluded_hits hits.txt
expect_eq "hits kept" "$(cat hits.txt)" "./src/app.json:7:credential-assignment"
 
# --- with nothing configured the files are left exactly as they were.
RELGATE_EXCLUDE=""
cp hits.txt hits.before
filter_excluded_hits hits.txt
expect_eq "no-op when unconfigured" "$(cmp -s hits.txt hits.before && echo same)" "same"
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures exclude test(s) failed"
  exit 1
fi
echo "exclude tests passed"