#!/usr/bin/env bash
# Unit tests for pro/scripts/cpm.sh - no dotnet or network (needs perl).
 
# shellcheck source=../../../pro/scripts/cpm.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../pro/scripts" && pwd)/cpm.sh"
 
failures=0
 
expect_eq() {
  if [ "$2" != "$3" ]; then
    echo "::error::$1: expected '$3', got '$2'"
    failures=$((failures + 1))
  fi
}
 
work="$(mktemp -d)"
cd "$work" || exit 1
 
# --- detection
mkdir on off nested
cat > on/Directory.Packages.props <<'EOF'
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
</Project>
EOF
cat > off/Directory.Packages.props <<'EOF'
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>false</ManagePackageVersionsCentrally>
  </PropertyGroup>
</Project>
EOF
cpm_detected_in on && got=yes || got=no
expect_eq "detects CPM on" "$got" "yes"
cpm_detected_in off && got=yes || got=no
expect_eq "ignores CPM off" "$got" "no"
cpm_detected_in nested && got=yes || got=no
expect_eq "no props file" "$got" "no"
 
# --- bumping
cat > Directory.Packages.props <<'EOF'
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
  </PropertyGroup>
  <ItemGroup>
    <PackageVersion Include="Newtonsoft.Json" Version="9.0.1" />
    <PackageVersion Version="9.0.1" Include="Other.Lib" />
    <PackageVersion Include="newtonsoft.json.bson" Version="9.0.1" />
    <PackageVersion Include="Pinned.Lib" Version="1.0.0" Condition="'$(TargetFramework)' == 'net6.0'" />
    <PackageVersion Include="Pinned.Lib" Version="2.0.0" Condition="'$(TargetFramework)' == 'net8.0'" />
    <PackageVersion Include="Ranged.Lib" Version="[1.0.0,2.0.0)" />
  </ItemGroup>
</Project>
EOF
 
version_of() { grep -o "Include=\"$1\"[^>]*" Directory.Packages.props | head -1; }
 
cpm_bump "Newtonsoft.Json" "9.0.1" "13.0.1"; rc=$?
expect_eq "bump returns success" "$rc" "0"
expect_eq "Include-before-Version bumped" \
  "$(grep -c '<PackageVersion Include="Newtonsoft.Json" Version="13.0.1" />' Directory.Packages.props)" "1"
expect_eq "similar package name untouched" \
  "$(grep -c 'newtonsoft.json.bson" Version="9.0.1"' Directory.Packages.props)" "1"
 
cpm_bump "Other.Lib" "9.0.1" "10.0.0"; rc=$?
expect_eq "Version-before-Include bumped" "$rc" "0"
expect_eq "Version-before-Include value" \
  "$(grep -c '<PackageVersion Version="10.0.0" Include="Other.Lib" />' Directory.Packages.props)" "1"
 
# Package name match is case-insensitive (NuGet ids are).
cpm_bump "Newtonsoft.Json.Bson" "9.0.1" "13.0.1"; rc=$?
expect_eq "case-insensitive id" "$rc" "0"
 
# Only the entry at the vulnerable version moves; the other TFM's doesn't.
cpm_bump "Pinned.Lib" "1.0.0" "1.5.0"; rc=$?
expect_eq "conditional entry bumped" "$rc" "0"
expect_eq "other TFM entry untouched" \
  "$(grep -c 'Pinned.Lib" Version="2.0.0"' Directory.Packages.props)" "1"
expect_eq "bumped TFM entry" \
  "$(grep -c 'Pinned.Lib" Version="1.5.0"' Directory.Packages.props)" "1"
 
# Nothing to do -> failure (caller reports it as not fixed).
cpm_bump "Newtonsoft.Json" "9.0.1" "13.0.1"; rc=$?
expect_eq "already bumped: no change" "$rc" "1"
cpm_bump "Missing.Lib" "1.0.0" "2.0.0"; rc=$?
expect_eq "unknown package: no change" "$rc" "1"
before=$(cksum < Directory.Packages.props)
cpm_bump "Ranged.Lib" "1.0.0" "2.0.0"; rc=$?
expect_eq "range not rewritten" "$rc" "1"
expect_eq "file untouched on no-op" "$(cksum < Directory.Packages.props)" "$before"
 
# Package ids with regex metacharacters are matched literally.
cat > Directory.Packages.props <<'EOF'
<Project><ItemGroup>
  <PackageVersion Include="A.B+C" Version="1.0.0" />
  <PackageVersion Include="AxB+C" Version="1.0.0" />
</ItemGroup></Project>
EOF
cpm_bump "A.B+C" "1.0.0" "2.0.0"; rc=$?
expect_eq "literal match bumped" "$rc" "0"
expect_eq "lookalike id untouched" \
  "$(grep -c 'AxB+C" Version="1.0.0"' Directory.Packages.props)" "1"
 
if [ "$failures" -ne 0 ]; then
  echo "::error::$failures cpm test(s) failed"
  exit 1
fi
echo "cpm tests passed"