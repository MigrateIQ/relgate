#!/usr/bin/env bash
# Sourced by auto-remediate.sh - not run directly.
#
# Central Package Management support. With CPM, package versions live in
# Directory.Packages.props as <PackageVersion Include="X" Version="Y" />
# rather than on each project's <PackageReference>, so `dotnet add package`
# is the wrong tool (it would put a Version on the reference and break the
# build). The props file is edited directly instead.
#
#   cpm_detected_in <dir>      true if a Directory.Packages.props under <dir>
#                              turns ManagePackageVersionsCentrally on
#   cpm_bump <pkg> <cur> <new> rewrite matching entries; returns 0 only if
#                              at least one file actually changed
#
# Only entries whose Version is exactly <cur> are rewritten, so a
# conditional entry pinned to a different version (e.g. per target
# framework) is never silently moved. VersionOverride on a project and
# version ranges/floating versions are left alone - the caller reports the
# package as not fixed rather than guessing.
 
cpm_props_files() {
  find "${1:-.}" -name 'Directory.Packages.props' \
    -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null
}
 
cpm_detected_in() {
  local f
  while IFS= read -r f; do
    if grep -q 'ManagePackageVersionsCentrally>[[:space:]]*true' "$f" 2>/dev/null; then
      return 0
    fi
  done < <(cpm_props_files "$1")
  return 1
}
 
cpm_bump() {
  local pkg="$1" cur="$2" target="$3" f before after changed=1
  while IFS= read -r f; do
    before=$(cksum < "$f")
    # Attribute order isn't fixed in XML, so handle Include-before-Version
    # and Version-before-Include. [^>]*? keeps each match inside one tag.
    PKG="$pkg" CUR="$cur" TARGET="$target" perl -0pi -e '
      s/(<PackageVersion\b[^>]*?\bInclude="\Q$ENV{PKG}\E"[^>]*?\bVersion=")\Q$ENV{CUR}\E(")/$1$ENV{TARGET}$2/gi;
      s/(<PackageVersion\b[^>]*?\bVersion=")\Q$ENV{CUR}\E("[^>]*?\bInclude="\Q$ENV{PKG}\E")/$1$ENV{TARGET}$2/gi;
    ' "$f"
    after=$(cksum < "$f")
    if [ "$before" != "$after" ]; then changed=0; fi
  done < <(cpm_props_files .)
  return $changed
}