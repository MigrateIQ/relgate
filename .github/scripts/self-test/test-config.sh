#!/usr/bin/env bash
# Unit tests for scripts/resolve-config.sh (needs yq and jq, both
# preinstalled on GitHub-hosted runners).
 
script="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../scripts" && pwd)/resolve-config.sh"
failures=0
 
expect_eq() {
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected '$3', got '$2'"
    failures=$((failures + 1))
  fi
}
 
work="$(mktemp -d)"
cd "$work" || exit 1
export GITHUB_OUTPUT="$work/out.txt"
 
# run [config-file-env]: runs the resolver, leaving output in out.txt and
# log in log.txt; echoes the exit code.
run() {
  : > "$GITHUB_OUTPUT"
  if [ $# -gt 0 ]; then export CONFIG_FILE="$1"; else unset CONFIG_FILE; fi
  bash "$script" > "$work/log.txt" 2>&1
  echo $?
}
val() { grep "^$1=" "$GITHUB_OUTPUT" | head -1 | cut -d= -f2-; }
excludes() { sed -n '/^exclude<</,/^RELGATE_EOF/p' "$GITHUB_OUTPUT" | sed '1d;$d'; }
 
# --- no config file: defaults.
expect_eq "absent: exit" "$(run)" "0"
expect_eq "absent: usings" "$(val usings_severity)" "blocking"
expect_eq "absent: nullable" "$(val nullable_severity)" "advisory"
expect_eq "absent: secrets" "$(val secrets_severity)" "blocking"
expect_eq "absent: vulns" "$(val vulns_severity)" "blocking"
expect_eq "absent: no excludes" "$(excludes)" ""
 
# --- a full, valid config.
cat > .relgate.yml <<'EOF'
version: 1
checks:
  unused-usings: advisory
  nullable-warnings: blocking
  secrets: off
  vulnerabilities: advisory
exclude:
  - "**/Migrations/**"
  - "*.Designer.cs"
EOF
expect_eq "full: exit" "$(run)" "0"
expect_eq "full: usings" "$(val usings_severity)" "advisory"
expect_eq "full: nullable" "$(val nullable_severity)" "blocking"
expect_eq "full: secrets" "$(val secrets_severity)" "off"
expect_eq "full: vulns" "$(val vulns_severity)" "advisory"
expect_eq "full: excludes" "$(excludes | tr '\n' ',')" "**/Migrations/**,*.Designer.cs,"
 
# --- partial config: unset checks keep their defaults.
printf 'checks:\n  nullable-warnings: off\n' > .relgate.yml
expect_eq "partial: exit" "$(run)" "0"
expect_eq "partial: usings default" "$(val usings_severity)" "blocking"
expect_eq "partial: nullable" "$(val nullable_severity)" "off"
 
# --- unquoted `off` is a YAML 1.1 boolean; it must still mean "off".
printf 'checks:\n  unused-usings: off\n  secrets: false\n' > .relgate.yml
expect_eq "bare off: exit" "$(run)" "0"
expect_eq "bare off: usings" "$(val usings_severity)" "off"
expect_eq "bare false: secrets" "$(val secrets_severity)" "off"
 
# --- empty file and comment-only file behave like no config.
: > .relgate.yml
expect_eq "empty: exit" "$(run)" "0"
expect_eq "empty: usings" "$(val usings_severity)" "blocking"
printf '# nothing here yet\n' > .relgate.yml
expect_eq "comments only: exit" "$(run)" "0"
 
# --- unknown keys warn but don't fail.
printf 'colour: blue\nchecks:\n  nullable-warning: off\n' > .relgate.yml
expect_eq "unknown keys: exit" "$(run)" "0"
expect_eq "unknown keys: warned twice" "$(grep -c '::warning::' "$work/log.txt")" "2"
expect_eq "unknown key typo did not apply" "$(val nullable_severity)" "advisory"
 
# --- invalid files fail loudly instead of falling back to defaults.
printf 'checks:\n  unused-usings: strict\n' > .relgate.yml
expect_eq "bad severity: exit" "$(run)" "1"
expect_eq "bad severity: message" "$(grep -c '::error::.*unused-usings' "$work/log.txt")" "1"
printf 'checks: [a, b]\n' > .relgate.yml
expect_eq "checks not a map: exit" "$(run)" "1"
printf 'exclude: "**/x/**"\n' > .relgate.yml
expect_eq "exclude not a list: exit" "$(run)" "1"
printf 'exclude:\n  - 1\n' > .relgate.yml
expect_eq "exclude non-string: exit" "$(run)" "1"
printf 'version: 2\n' > .relgate.yml
expect_eq "future version: exit" "$(run)" "1"
printf 'checks: {unclosed\n' > .relgate.yml
expect_eq "invalid yaml: exit" "$(run)" "1"
printf -- '- just\n- a list\n' > .relgate.yml
expect_eq "top-level list: exit" "$(run)" "1"
 
# --- an explicitly named file that doesn't exist is an error.
expect_eq "explicit missing: exit" "$(run custom.yml)" "1"
printf 'checks:\n  secrets: advisory\n' > custom.yml
expect_eq "explicit file: exit" "$(run custom.yml)" "0"
expect_eq "explicit file: secrets" "$(val secrets_severity)" "advisory"
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures config test(s) failed"
  exit 1
fi
echo "config tests passed"