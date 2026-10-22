#!/usr/bin/env bash
# Unit tests for pro/scripts/generate-sarif.sh - no dotnet or network.
 
# Git Bash on Windows rewrites "/ws/"-style arguments into Windows paths;
# no effect on Linux runners.
export MSYS_NO_PATHCONV=1
 
script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../pro/scripts" && pwd)/generate-sarif.sh"
failures=0
 
expect_eq() {
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected '$3', got '$2'"
    failures=$((failures + 1))
  fi
}
 
work="$(mktemp -d)"
cd "$work" || exit 1
export GITHUB_WORKSPACE=/ws RUNNER_TEMP="$work" GITHUB_OUTPUT="$work/out.txt"
 
# --- No findings at all: still a valid, empty SARIF file.
bash "$script"
expect_eq "empty: version" "$(jq -r .version relgate.sarif)" "2.1.0"
expect_eq "empty: results" "$(jq '.runs[0].results | length' relgate.sarif)" "0"
expect_eq "path output" "$(cat out.txt)" "path=$work/relgate.sarif"
 
# --- Findings from every source.
printf '%s\r\n' \
  '/ws/src/A.cs(3,1): warning IDE0005: Using directive is unnecessary. [/ws/p.csproj]' \
  '/ws/src/A.cs(3,1): warning IDE0005: Using directive is unnecessary. [/ws/p.csproj]' \
  > usings-output.txt
printf '%s\n' '/ws/src/B.cs(10,5): warning CS8602' > nullable-diagnostics.txt
printf '%s\n' './config/app.json:4:credential-assignment' > secret-hits.txt
cat > vuln-output.json <<'EOF'
{"projects":[{"path":"/ws/App.csproj","frameworks":[
 {"topLevelPackages":[{"id":"Newtonsoft.Json","resolvedVersion":"9.0.1",
   "vulnerabilities":[{"severity":"High","advisoryurl":"https://github.com/advisories/GHSA-1"}]}],
  "transitivePackages":[{"id":"Some.Lib","resolvedVersion":"1.0.0",
   "vulnerabilities":[{"severity":"Low","advisoryurl":"https://github.com/advisories/GHSA-2"}]}]},
 {"topLevelPackages":[{"id":"Newtonsoft.Json","resolvedVersion":"9.0.1",
   "vulnerabilities":[{"severity":"High","advisoryurl":"https://github.com/advisories/GHSA-1"}]}]}]}]}
EOF
 
bash "$script"
sarif=relgate.sarif
by_rule() { jq "[.runs[0].results[] | select(.ruleId == \"$1\")] | length" $sarif; }
expect_eq "usings deduped" "$(by_rule RG001)" "1"
expect_eq "nullable" "$(by_rule RG002)" "1"
expect_eq "secrets" "$(by_rule RG003)" "1"
expect_eq "vulns deduped across frameworks" "$(by_rule RG004)" "2"
 
expect_eq "usings uri relative" \
  "$(jq -r '.runs[0].results[] | select(.ruleId=="RG001") | .locations[0].physicalLocation.artifactLocation.uri' $sarif)" \
  "src/A.cs"
expect_eq "usings line" \
  "$(jq -r '.runs[0].results[] | select(.ruleId=="RG001") | .locations[0].physicalLocation.region.startLine' $sarif)" "3"
expect_eq "secret uri strips ./" \
  "$(jq -r '.runs[0].results[] | select(.ruleId=="RG003") | .locations[0].physicalLocation.artifactLocation.uri' $sarif)" \
  "config/app.json"
expect_eq "vuln High is error" \
  "$(jq -r '.runs[0].results[] | select(.ruleId=="RG004" and (.message.text | contains("Newtonsoft"))) | .level' $sarif)" "error"
expect_eq "vuln Low is note" \
  "$(jq -r '.runs[0].results[] | select(.ruleId=="RG004" and (.message.text | contains("Some.Lib"))) | .level' $sarif)" "note"
expect_eq "vuln uri relative" \
  "$(jq -r '.runs[0].results[] | select(.ruleId=="RG004") | .locations[0].physicalLocation.artifactLocation.uri' $sarif | sort -u)" \
  "App.csproj"
 
# Every result's ruleId must be declared in the driver's rules.
expect_eq "rules declared" "$(jq '
  [.runs[0].tool.driver.rules[].id] as $ids |
  [.runs[0].results[] | select(.ruleId as $r | $ids | index($r) | not)] |
  length' $sarif)" "0"
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures sarif test(s) failed"
  exit 1
fi
echo "sarif tests passed"