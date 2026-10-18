#!/usr/bin/env bash
# Packs the Spec Kit extension and preset into the zips a release carries.
#
#   scripts/build-release.sh          -> dist/gemeinde-extension-<v>.zip, dist/gemeinde-preset-<v>.zip
#
# The version comes from each manifest, so a release is: bump the version in
# extension.yml and/or preset.yml, run this, then
#   gh release create v<version> dist/*.zip
# Projects install from the release asset URL (README.md), which pins the version.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
dist="$root/dist"
rm -rf "$dist"
mkdir -p "$dist"

version_of() {
  sed -n 's/^  version: "\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' "$1" | head -1
}

pack() {
  local kind="$1" dir="$root/speckit/$1" manifest="$2"
  local version
  version="$(version_of "$dir/$manifest")"
  [ -n "$version" ] || { echo "no version in $dir/$manifest" >&2; exit 1; }
  # Manifest at the archive root, which is what `specify ... add --from` expects.
  python3 - "$dir" "$dist/gemeinde-$kind-$version.zip" <<'PY'
import os, sys, zipfile
src, out = sys.argv[1], sys.argv[2]
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    for base, _, files in sorted(os.walk(src)):
        for name in sorted(files):
            path = os.path.join(base, name)
            z.write(path, os.path.relpath(path, src))
PY
  echo "dist/gemeinde-$kind-$version.zip"
}

pack extension extension.yml
pack preset preset.yml
