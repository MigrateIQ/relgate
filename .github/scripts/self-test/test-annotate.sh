#!/usr/bin/env bash
# Unit tests for scripts/annotate.sh - no dotnet needed.
 
# shellcheck source=../../../scripts/annotate.sh
. "$(dirname "${BASH_SOURCE[0]}")/../../../scripts/annotate.sh"
 
failures=0
export GITHUB_WORKSPACE=/ws
pattern='[^ ]+\([0-9]+,[0-9]+\): (warning|error) IDE0005'
 
expect_eq() {
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected '$3', got '$2'"
    failures=$((failures + 1))
  fi
}
 
tmp="$(mktemp)"
 
# Path made repo-relative, duplicate lines (build recap) collapsed, CRLF ok.
printf '%s\r\n' \
  '/ws/src/A.cs(3,1): warning IDE0005: Using directive is unnecessary. [/ws/p.csproj]' \
  '/ws/src/A.cs(3,1): warning IDE0005: Using directive is unnecessary. [/ws/p.csproj]' \
  > "$tmp"
out=$(emit_annotations error "Unused using" "$pattern" "$tmp")
expect_eq "relative path + dedupe" "$out" \
  "::error file=src/A.cs,line=3,title=Unused using::IDE0005"
 
# Empty / missing input emits nothing and doesn't fail.
: > "$tmp"
expect_eq "empty file" "$(emit_annotations error T "$pattern" "$tmp")" ""
expect_eq "missing file" \
  "$(emit_annotations error T "$pattern" "$tmp.nope")" ""
 
# More than MAX_ANNOTATIONS: first N annotated, remainder summarised once.
: > "$tmp"
for i in 1 2 3 4 5; do
  echo "/ws/B.cs($i,1): warning IDE0005" >> "$tmp"
done
out=$(MAX_ANNOTATIONS=2 emit_annotations warning "Unused using" "$pattern" "$tmp")
expect_eq "annotation count" "$(grep -c '^::warning' <<< "$out")" "2"
expect_eq "overflow notice" "$(grep -c '^::notice::.*3 more' <<< "$out")" "1"
 
# Special characters in the path are escaped for the command syntax.
printf '%s\n' '/ws/we,ird:dir/C.cs(7,2): warning IDE0005' > "$tmp"
out=$(emit_annotations error T "$pattern" "$tmp")
expect_eq "escaping" "$out" \
  "::error file=we%2Cird%3Adir/C.cs,line=7,title=T::IDE0005"
 
rm -f "$tmp"
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures annotate test(s) failed"
  exit 1
fi
echo "annotate tests passed"