#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH, VULN_THRESHOLD
# Outputs: score, failed, scan_error
 
path_args=()
if [ -n "$PROJECT_PATH" ]; then
  path_args=("$PROJECT_PATH")
fi
 
dotnet list "${path_args[@]}" package --vulnerable \
  --include-transitive --format json \
  > vuln-output.json 2>vuln-output.err
list_exit=$?
 
if [ "$list_exit" -ne 0 ]; then
  echo "::warning::RelGate Pro: vulnerability scan failed to run."
  echo "score=" >> "$GITHUB_OUTPUT"
  echo "failed=true" >> "$GITHUB_OUTPUT"
  echo "scan_error=true" >> "$GITHUB_OUTPUT"
  exit 0
fi
echo "scan_error=false" >> "$GITHUB_OUTPUT"
 
# One entry per distinct (package, resolved version, advisory) - the same
# vulnerable package shows up once per target framework (and per project),
# and counting each copy would punish multi-targeting repos several times
# over for a single underlying problem.
penalty=0
while IFS= read -r severity; do
  severity="${severity%$'\r'}"
  case "$severity" in
    Critical) penalty=$((penalty + 40)) ;;
    High) penalty=$((penalty + 20)) ;;
    Moderate) penalty=$((penalty + 10)) ;;
    Low) penalty=$((penalty + 5)) ;;
  esac
done < <(jq -r '
  [.projects[]?.frameworks[]? |
   (.topLevelPackages[]?, .transitivePackages[]?) |
   .id as $id | .resolvedVersion as $v |
   .vulnerabilities[]? |
   {id: $id, v: $v, url: .advisoryurl, sev: .severity}] |
  unique_by([.id, .v, .url]) | .[].sev // empty
' vuln-output.json)
 
score=$((100 - penalty))
if [ "$score" -lt 0 ]; then
  score=0
fi
echo "score=$score" >> "$GITHUB_OUTPUT"
 
if [ "$score" -lt "$VULN_THRESHOLD" ]; then
  echo "failed=true" >> "$GITHUB_OUTPUT"
else
  echo "failed=false" >> "$GITHUB_OUTPUT"
fi