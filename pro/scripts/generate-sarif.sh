#!/usr/bin/env bash
# Inputs (env): GITHUB_WORKSPACE, RUNNER_TEMP (optional, defaults to .)
# Reads (all optional, whatever earlier steps left in the workspace):
#   usings-output.txt, nullable-diagnostics.txt, secret-hits.txt,
#   vuln-output.json
# Outputs: path
#
# Builds one SARIF 2.1.0 file from RelGate's findings so they can be
# uploaded to GitHub code scanning. Like everything else here it never
# contains a matched secret value - only file, line and pattern type.
 
out="${RUNNER_TEMP:-.}/relgate.sarif"
workspace="${GITHUB_WORKSPACE:-}/"
 
# MSBuild-style diagnostics ("path(line,col): warning CODE") -> SARIF
# results. usage: diag_results <file> <pattern> <ruleId> <level> <text>
diag_results() {
  local file="$1" pattern="$2" rule="$3" level="$4" text="$5"
  if [ ! -s "$file" ]; then echo '[]'; return; fi
  grep -oE "$pattern" "$file" | tr -d '\r' | sort -u \
    | jq -R -s --arg rule "$rule" --arg level "$level" --arg text "$text" \
        --arg ws "$workspace" '
      split("\n") | map(select(length > 0)) |
      map(capture("^(?<path>[^ ]+)\\((?<line>[0-9]+),(?<col>[0-9]+)\\): \\w+ (?<code>\\S+)$")) |
      map({
        ruleId: $rule,
        level: $level,
        message: {text: "\($text) (\(.code))"},
        locations: [{physicalLocation: {
          artifactLocation: {uri: (.path | ltrimstr($ws))},
          region: {startLine: (.line | tonumber),
                   startColumn: (.col | tonumber)}
        }}]
      })'
}
 
usings=$(diag_results usings-output.txt \
  '[^ ]+\([0-9]+,[0-9]+\): (warning|error) IDE0005' \
  RG001 error "Unused using directive")
 
nullable=$(diag_results nullable-diagnostics.txt \
  '[^ ]+\([0-9]+,[0-9]+\): warning CS8[0-9]{3}' \
  RG002 warning "Nullable reference warning")
 
# secret-hits.txt is file:line:type per line.
if [ -s secret-hits.txt ]; then
  secrets=$(jq -R -s '
    split("\n") | map(select(length > 0)) |
    map(split(":") | {file: .[0], line: (.[1] | tonumber), type: .[2]}) |
    map({
      ruleId: "RG003",
      level: "error",
      message: {text: "Potential secret (\(.type)) - value not shown"},
      locations: [{physicalLocation: {
        artifactLocation: {uri: (.file | ltrimstr("./"))},
        region: {startLine: .line}
      }}]
    })' secret-hits.txt)
else
  secrets='[]'
fi
 
# One result per distinct (package, version, advisory), same dedupe as the
# readiness score. dotnet list gives project paths, not source lines, so
# the finding is pinned to line 1 of the project file.
if [ -s vuln-output.json ]; then
  vulns=$(jq --arg ws "$workspace" '
    [.projects[]? | .path as $proj | .frameworks[]? |
     (.topLevelPackages[]?, .transitivePackages[]?) |
     .id as $id | .resolvedVersion as $v |
     .vulnerabilities[]? |
     {proj: $proj, id: $id, v: $v, url: .advisoryurl, sev: .severity}] |
    unique_by([.id, .v, .url]) |
    map({
      ruleId: "RG004",
      level: (if .sev == "Critical" or .sev == "High" then "error"
              elif .sev == "Moderate" then "warning"
              else "note" end),
      message: {text: "\(.id) \(.v) has a \(.sev) vulnerability: \(.url)"},
      locations: [{physicalLocation: {
        artifactLocation: {uri: (.proj | ltrimstr($ws))},
        region: {startLine: 1}
      }}]
    })' vuln-output.json 2>/dev/null) || vulns='[]'
  [ -n "$vulns" ] || vulns='[]'
else
  vulns='[]'
fi
 
jq -n \
  --argjson usings "$usings" --argjson nullable "$nullable" \
  --argjson secrets "$secrets" --argjson vulns "$vulns" '
  {
    version: "2.1.0",
    "$schema": "https://json.schemastore.org/sarif-2.1.0.json",
    runs: [{
      tool: {driver: {
        name: "RelGate",
        informationUri: "https://github.com/MigrateIQ/relgate",
        rules: [
          {id: "RG001", name: "UnusedUsing",
           shortDescription: {text: "Unused using directive (IDE0005)"}},
          {id: "RG002", name: "NullableWarning",
           shortDescription: {text: "Nullable reference type warning"}},
          {id: "RG003", name: "PotentialSecret",
           shortDescription: {text: "Potential leaked credential"}},
          {id: "RG004", name: "VulnerablePackage",
           shortDescription: {text: "NuGet package with a known vulnerability"}}
        ]
      }},
      results: ($usings + $nullable + $secrets + $vulns)
    }]
  }' > "$out"
 
echo "path=$out" >> "${GITHUB_OUTPUT:-/dev/null}"