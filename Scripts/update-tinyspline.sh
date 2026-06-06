#!/usr/bin/env bash
#
# Re-vendor the TinySpline C/C++ sources from a pinned upstream tag.
#
# We vendor (commit) the upstream sources rather than use a git submodule,
# because SwiftPM clones dependencies WITHOUT submodules — a submodule'd source
# tree would be empty at a consumer's build time. This script keeps the vendored
# copy reproducible: it clones the pinned tag into a temp dir and copies the
# exact files we build.
#
# Usage:
#   Scripts/update-tinyspline.sh [TAG]
#
# TAG defaults to the version recorded in TINYSPLINE_VERSION below.

set -euo pipefail

TINYSPLINE_VERSION="v0.6.0"
TINYSPLINE_REPO="https://github.com/msteinbeck/tinyspline.git"

TAG="${1:-$TINYSPLINE_VERSION}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$ROOT/Sources/CTinySpline"
INCLUDE="$DEST/include"

# Files we compile / expose.
SOURCES=(tinyspline.c parson.c tinysplinecxx.cxx)
HEADERS=(tinyspline.h parson.h tinysplinecxx.h)

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Cloning tinyspline $TAG ..."
git clone --depth 1 --branch "$TAG" "$TINYSPLINE_REPO" "$TMP/tinyspline"
SRC="$TMP/tinyspline/src"

echo "Copying sources -> $DEST"
for f in "${SOURCES[@]}"; do
	cp "$SRC/$f" "$DEST/$f"
done

echo "Copying headers  -> $INCLUDE"
for f in "${HEADERS[@]}"; do
	cp "$SRC/$f" "$INCLUDE/$f"
done

cp "$TMP/tinyspline/LICENSE" "$ROOT/LICENSE.tinyspline"

# Record exactly what we vendored.
COMMIT="$(git -C "$TMP/tinyspline" rev-parse HEAD)"
cat > "$DEST/UPSTREAM.txt" <<EOF
tinyspline vendored sources
repo:    $TINYSPLINE_REPO
tag:     $TAG
commit:  $COMMIT
Re-sync with: Scripts/update-tinyspline.sh $TAG
NOTE: include/tinyspline_swift_shim.h and include/module.modulemap are
maintained by this package and are NOT overwritten by this script.
EOF

echo "Done. Vendored $TAG ($COMMIT)."
echo "Now run: swift build && swift test"
