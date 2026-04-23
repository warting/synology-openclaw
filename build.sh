#!/bin/sh
# Build a Synology .spk for OpenClaw.
#
# Usage:
#   ./build.sh                       # defaults to 0.0.0-dev-<epoch>
#   ./build.sh 0.1.0-0001
#   ./build.sh 0.1.0-0001 2026.4.10  # also pin the OpenClaw image tag
#
# Output: build/openclaw-<version>.spk
set -eu

VERSION="${1:-0.0.0-dev-$(date +%s)}"
IMAGE_TAG="${2:-latest}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$ROOT/build/stage"
OUT="$ROOT/build/openclaw-${VERSION}.spk"

rm -rf "$ROOT/build"
mkdir -p "$STAGE"

# 1. Copy the SPK source tree into the staging dir.
cp -R "$ROOT/src/." "$STAGE/"

# 2. Render INFO from template.
sed -e "s|\${VERSION}|$VERSION|g" "$STAGE/INFO.template" > "$STAGE/INFO"
rm "$STAGE/INFO.template"

# 3. Pin the image tag in the bundled compose file (keeps .spk immutable per build).
if [ "$IMAGE_TAG" != "latest" ]; then
    sed -i.bak -e "s|openclaw:latest|openclaw:$IMAGE_TAG|g" \
        "$STAGE/package/docker-compose.yml"
    rm -f "$STAGE/package/docker-compose.yml.bak"
fi

# 4. Pack package/ into package.tgz at the staging root.
#    (package.tgz is what DSM extracts into $SYNOPKG_PKGDEST at install time.)
(cd "$STAGE/package" && tar czf "$STAGE/package.tgz" .)
rm -rf "$STAGE/package"

# 5. Make scripts executable.
chmod 755 "$STAGE/scripts/"*

# 6. Tar everything into the .spk. SPK = plain tar, not gzipped.
(cd "$STAGE" && tar cf "$OUT" .)

SIZE=$(wc -c < "$OUT" | tr -d ' ')
SHA256=$(shasum -a 256 "$OUT" | awk '{print $1}')

echo ""
echo "Built: $OUT"
echo "  version: $VERSION"
echo "  image:   ghcr.io/openclaw/openclaw:$IMAGE_TAG"
echo "  size:    $SIZE bytes"
echo "  sha256:  $SHA256"
