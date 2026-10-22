#!/usr/bin/env bash
# Inputs (env): CONFIG_FILE (default .relgate.yml)
# Outputs: usings_severity, nullable_severity, secrets_severity,
#          vulns_severity, exclude (newline-separated globs)
#
# Reads the optional .relgate.yml. The file owns what has no workflow input:
# per-check severity and path excludes. Runtime settings (dotnet-version,
# project-path, thresholds, ...) stay workflow inputs, so a value is never
# set in two places.
#
#   version: 1
#   checks:
#     unused-usings: blocking      # blocking | advisory | off
#     nullable-warnings: advisory
#     secrets: blocking            # Pro
#     vulnerabilities: blocking    # Pro
#   exclude:                       # findings in matching files are ignored
#     - "**/Migrations/**"
#     - "**/*.Designer.cs"
#
# An invalid file fails loudly (::error + exit 1) rather than falling back
# to defaults - a typo must not silently weaken the gate. Unknown keys only
# warn, so a newer file still works on an older release.
 
config_file="${CONFIG_FILE:-.relgate.yml}"
 
usings=blocking
nullable=advisory
secrets=blocking
vulns=blocking
exclude_json='[]'
 
emit() {
  local delim="RELGATE_EOF_$RANDOM$RANDOM"
  {
    echo "usings_severity=$usings"
    echo "nullable_severity=$nullable"
    echo "secrets_severity=$secrets"
    echo "vulns_severity=$vulns"
    echo "exclude<<$delim"
    jq -r '.[]' <<< "$exclude_json"
    echo "$delim"
  } >> "$GITHUB_OUTPUT"
}
 
fail() {
  echo "::error::RelGate config ($config_file): $1"
  exit 1
}
 
if [ ! -f "$config_file" ]; then
  # Absent default file = defaults. An explicitly named file that's missing
  # is a mistake worth surfacing.
  if [ "$config_file" != ".relgate.yml" ]; then
    fail "file not found."
  fi
  emit
  exit 0
fi
 
if ! command -v yq >/dev/null 2>&1; then
  fail "yq is required to read the config file (preinstalled on GitHub-hosted runners)."
fi
if ! json=$(yq -o=json '.' "$config_file" 2>/dev/null); then
  fail "not valid YAML."
fi
 
# An empty file parses to null - treat it like no config.
if [ "$json" = "null" ] || [ -z "$json" ]; then
  emit
  exit 0
fi
if ! jq -e 'type == "object"' <<< "$json" >/dev/null; then
  fail "top level must be a mapping."
fi
 
# Unknown keys are most likely typos - say so, but don't fail.
for key in $(jq -r 'keys[] | select(. != "version" and . != "checks" and . != "exclude")' <<< "$json"); do
  echo "::warning::RelGate config ($config_file): unknown top-level key '$key' ignored."
done
 
version=$(jq -r '.version // 1' <<< "$json")
[ "$version" = "1" ] || fail "unsupported version '$version' (expected 1)."
 
if jq -e 'has("checks") and (.checks | type != "object")' <<< "$json" >/dev/null; then
  fail "'checks' must be a mapping."
fi
for key in $(jq -r '(.checks // {}) | keys[] | select(. != "unused-usings" and . != "nullable-warnings" and . != "secrets" and . != "vulnerabilities")' <<< "$json"); do
  echo "::warning::RelGate config ($config_file): unknown check '$key' ignored."
done
 
# YAML 1.1 reads a bare `off` as false; treat that as the intended 'off'.
# severity <check-key> <target-variable>: sets the variable only when the
# file gives a value, so defaults stand otherwise. Assigns directly (no
# command substitution) so fail's ::error:: line reaches the log.
severity() {
  local check="$1" target="$2" value
  value=$(jq -r --arg k "$check" '(.checks // {})[$k] | if . == null then "" else tostring end' <<< "$json")
  [ "$value" = "false" ] && value=off
  case "$value" in
    "") ;;
    blocking | advisory | off) printf -v "$target" '%s' "$value" ;;
    *) fail "checks.$check must be blocking, advisory or off (got '$value')." ;;
  esac
}
severity unused-usings usings
severity nullable-warnings nullable
severity secrets secrets
severity vulnerabilities vulns
 
if jq -e 'has("exclude") and (.exclude | type != "array" or any(.[]; type != "string"))' <<< "$json" >/dev/null; then
  fail "'exclude' must be a list of glob strings."
fi
exclude_json=$(jq -c '.exclude // []' <<< "$json")
 
emit