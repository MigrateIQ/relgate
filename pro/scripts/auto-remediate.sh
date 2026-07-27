#!/usr/bin/env bash
# Inputs (env): PROJECT_PATH, GITHUB_TOKEN, HEAD_REF, IS_FORK
# Outputs: fixed_count, candidate_count, outcome, commit_sha
#
# v1 scope: top-level PackageReference vulnerabilities in non-CPM projects
# only. Transitive-only vulnerabilities and Central Package Management
# projects are reported as out of scope, not attempted - fixing either
# safely needs more than this script does today. Reuses vuln-output.json
# already written by vuln-scan.sh; no second `dotnet list` call.

already_fixed=0
candidate_count=0
bumped_this_run=0
commit_sha=""

# Version helpers - NuGet versions here are plain dotted-numeric, so
# `sort -V` is a reliable ordering; used both to pick the max patched
# version across advisories and to evaluate `vulnerable_version_range`
# strings like ">= 4.0.0, < 4.5.1" against the currently resolved version.
vercmp() {
  if [ "$1" = "$2" ]; then echo 0; return; fi
  local higher
  higher=$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -1)
  if [ "$higher" = "$1" ]; then echo 1; else echo -1; fi
}
vercmp_ge() { [ "$(vercmp "$1" "$2")" -ge 0 ]; }
vercmp_gt() { [ "$(vercmp "$1" "$2")" -gt 0 ]; }
vercmp_le() { [ "$(vercmp "$1" "$2")" -le 0 ]; }
vercmp_lt() { [ "$(vercmp "$1" "$2")" -lt 0 ]; }

version_satisfies() {
  local ver="$1" range="$2" ok=true constraint op cver parts
  IFS=',' read -ra parts <<< "$range"
  for constraint in "${parts[@]}"; do
    constraint=$(printf '%s' "$constraint" | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
    op=$(printf '%s' "$constraint" | grep -oE '^(>=|<=|>|<|=)')
    cver=$(printf '%s' "$constraint" | sed -E 's/^(>=|<=|>|<|=)[[:space:]]*//')
    case "$op" in
      ">=") vercmp_ge "$ver" "$cver" || ok=false ;;
      ">")  vercmp_gt "$ver" "$cver" || ok=false ;;
      "<=") vercmp_le "$ver" "$cver" || ok=false ;;
      "<")  vercmp_lt "$ver" "$cver" || ok=false ;;
      "=")  [ "$ver" = "$cver" ] || ok=false ;;
      *) ok=false ;;
    esac
  done
  [ "$ok" = "true" ]
}

emit() {
  echo "fixed_count=$1" >> "$GITHUB_OUTPUT"
  echo "candidate_count=$candidate_count" >> "$GITHUB_OUTPUT"
  echo "outcome=$2" >> "$GITHUB_OUTPUT"
  echo "commit_sha=$commit_sha" >> "$GITHUB_OUTPUT"
}

if [ "$IS_FORK" = "true" ]; then
  echo "::notice::RelGate Pro: auto-remediate skipped - fork PRs can't receive pushed fixes."
  emit 0 "fork"
  exit 0
fi

if [ ! -s vuln-output.json ]; then
  emit 0 "no-candidates"
  exit 0
fi

# A repo-wide Central Package Management setup changes how `dotnet add
# package` needs to behave; skip remediation entirely rather than risk a
# bad edit against a pattern this script doesn't understand yet.
cpm_detected=false
while IFS= read -r f; do
  if grep -q 'ManagePackageVersionsCentrally>[[:space:]]*true' "$f" 2>/dev/null; then
    cpm_detected=true
  fi
done < <(find . -name 'Directory.Packages.props' \
  -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null)

if [ "$cpm_detected" = "true" ]; then
  echo "::notice::RelGate Pro: auto-remediate skipped - repo uses Central Package Management, not supported in v1."
  emit 0 "cpm"
  exit 0
fi

# One row per (project, package, framework, vulnerability) - a package can
# have several vulnerabilities and appear under several target frameworks.
candidates_raw=$(jq -r '
  .projects[]? |
  .path as $proj |
  .frameworks[]? |
  .topLevelPackages[]? |
  select(.vulnerabilities and (.vulnerabilities | length) > 0) |
  . as $p |
  .vulnerabilities[] |
  [$proj, $p.id, $p.resolvedVersion, .advisoryurl] | @tsv
' vuln-output.json 2>/dev/null | tr -d '\r')

transitive_count=$(jq '
  [.projects[]? | .frameworks[]? | .transitivePackages[]? |
   select(.vulnerabilities and (.vulnerabilities | length) > 0)] | length
' vuln-output.json 2>/dev/null)
if [ -n "$transitive_count" ] && [ "$transitive_count" -gt 0 ] 2>/dev/null; then
  echo "::notice::RelGate Pro: $transitive_count transitive-dependency vulnerability(ies) found - not auto-remediated in v1, see the vulnerability score above."
fi

if [ -z "$candidates_raw" ]; then
  emit 0 "no-candidates"
  exit 0
fi

pairs=$(printf '%s\n' "$candidates_raw" | cut -f1,2 | sort -u)
declare -A ghsa_cache
touched_any=false

# An empty bearer token is rejected outright (401) rather than falling
# back to anonymous, so only send the header when there's a real token -
# GITHUB_TOKEN is always non-empty in an actual workflow run.
auth_args=()
if [ -n "$GITHUB_TOKEN" ]; then
  auth_args=(-H "Authorization: Bearer $GITHUB_TOKEN")
fi

while IFS=$'\t' read -r proj pkg; do
  [ -z "$proj" ] && continue
  candidate_count=$((candidate_count + 1))

  current=$(printf '%s\n' "$candidates_raw" | awk -F'\t' -v p="$proj" -v k="$pkg" \
    '$1==p && $2==k {print $3; exit}')
  advisories=$(printf '%s\n' "$candidates_raw" | awk -F'\t' -v p="$proj" -v k="$pkg" \
    '$1==p && $2==k {print $4}' | sort -u)

  target=""
  while IFS= read -r advisory_url; do
    [ -z "$advisory_url" ] && continue
    ghsa_id=$(basename "$advisory_url")

    # Cached per-advisory (not per-package-version): a GHSA can list
    # several affected ranges with different fix versions - e.g. one
    # patch for the 4.x line, another for 5.x - so the raw range/patch
    # pairs are cached once and matched against $current below, rather
    # than caching a single resolved "the" patched version.
    if [ -n "${ghsa_cache[$ghsa_id]+set}" ]; then
      ranges_and_patches="${ghsa_cache[$ghsa_id]}"
    else
      resp=$(curl -sf --max-time 10 \
        "${auth_args[@]}" \
        -H "Accept: application/vnd.github+json" \
        "https://api.github.com/advisories/$ghsa_id" 2>/dev/null)
      if [ -z "$resp" ]; then
        echo "::warning::RelGate Pro: advisory lookup failed for $ghsa_id ($pkg) - leaving it for a future run."
        ranges_and_patches=""
      else
        ranges_and_patches=$(printf '%s' "$resp" | jq -r --arg pkg "$pkg" '
          .vulnerabilities[]? |
          select(.package.ecosystem == "nuget") |
          select((.package.name | ascii_downcase) == ($pkg | ascii_downcase)) |
          [(.vulnerable_version_range // ""), (.first_patched_version // "")] | @tsv
        ' | tr -d '\r')
      fi
      ghsa_cache[$ghsa_id]="$ranges_and_patches"
    fi

    [ -z "$ranges_and_patches" ] && continue

    advisory_patch=""
    fallback_max=""
    while IFS=$'\t' read -r range patch; do
      [ -z "$patch" ] && continue
      if [ -z "$fallback_max" ]; then
        fallback_max="$patch"
      else
        fallback_max=$(printf '%s\n%s\n' "$fallback_max" "$patch" | sort -V | tail -1)
      fi
      if [ -n "$range" ] && version_satisfies "$current" "$range"; then
        if [ -z "$advisory_patch" ]; then
          advisory_patch="$patch"
        else
          advisory_patch=$(printf '%s\n%s\n' "$advisory_patch" "$patch" | sort -V | tail -1)
        fi
      fi
    done <<< "$ranges_and_patches"

    # No range matched $current (shouldn't normally happen - dotnet
    # already told us this package/version is vulnerable) - fall back to
    # the highest known patched version rather than skipping the fix.
    if [ -z "$advisory_patch" ]; then
      advisory_patch="$fallback_max"
    fi

    if [ -n "$advisory_patch" ]; then
      if [ -z "$target" ]; then
        target="$advisory_patch"
      else
        target=$(printf '%s\n%s\n' "$target" "$advisory_patch" | sort -V | tail -1)
      fi
    fi
  done <<< "$advisories"

  if [ -z "$target" ]; then
    echo "::notice::RelGate Pro: no patched version available yet for $pkg in $proj - leaving as-is."
    continue
  fi

  highest=$(printf '%s\n%s\n' "$current" "$target" | sort -V | tail -1)
  if [ "$highest" = "$current" ]; then
    already_fixed=$((already_fixed + 1))
    continue
  fi

  echo "Bumping $pkg $current -> $target in $proj"
  if dotnet add "$proj" package "$pkg" --version "$target" >/dev/null 2>&1; then
    touched_any=true
    bumped_this_run=$((bumped_this_run + 1))
  else
    echo "::warning::RelGate Pro: failed to apply $pkg@$target in $proj - leaving as-is."
  fi
done <<< "$pairs"

if [ "$touched_any" != "true" ]; then
  emit "$already_fixed" "ok"
  exit 0
fi

build_path_args=()
if [ -n "$PROJECT_PATH" ]; then
  build_path_args=("$PROJECT_PATH")
fi

if ! dotnet build "${build_path_args[@]}" >/dev/null 2>&1; then
  echo "::warning::RelGate Pro: auto-remediation would break the build - discarding the fix, no commit was made. (A clean build isn't the same as a correct one; no tests were run as part of this.)"
  git checkout -- . 2>/dev/null
  emit "$already_fixed" "build-failed"
  exit 0
fi

mapfile -t changed_files < <(git diff --name-only -- '*.csproj')
if [ "${#changed_files[@]}" -eq 0 ]; then
  emit "$already_fixed" "ok"
  exit 0
fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add -- "${changed_files[@]}"
git commit -m "chore(relgate): auto-remediate vulnerable package(s)" >/dev/null 2>&1

if git push origin "HEAD:$HEAD_REF" 2>/dev/null; then
  commit_sha=$(git rev-parse --short HEAD)
  emit "$((already_fixed + bumped_this_run))" "ok"
else
  echo "::warning::RelGate Pro: fix committed locally but the push failed (branch protection or a concurrent update?) - see logs."
  emit "$already_fixed" "push-failed"
fi
