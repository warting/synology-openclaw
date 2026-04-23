#!/bin/sh
# Build a Synology .spk for OpenClaw.
#
# Usage:
#   ./build.sh                       # defaults to 0.0.0-dev-<epoch>
#   ./build.sh 0.1.0-0001
#   ./build.sh 0.1.0-0001 2026.4.10  # also pin the OpenClaw image tag
#
# Output: build/openclaw-<version>.spk
#
# SPK is a *plain tar* (not gzip), GNU-format, with root:root ownership,
# and flat top-level entries (no "./" prefix). Synology's Package Center
# rejects archives that don't match this shape.
set -eu

VERSION="${1:-0.0.0-dev-$(date +%s)}"
IMAGE_TAG="${2:-latest}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
STAGE="$ROOT/build/stage"
OUT="$ROOT/build/openclaw-${VERSION}.spk"

rm -rf "$ROOT/build"
mkdir -p "$STAGE"

# macOS: don't include ._* AppleDouble metadata in tar.
export COPYFILE_DISABLE=1

# 1. Copy SPK source into stage.
cp -R "$ROOT/src/." "$STAGE/"

# 2. Render INFO from template.
sed -e "s|\${VERSION}|$VERSION|g" "$STAGE/INFO.template" > "$STAGE/INFO"
rm "$STAGE/INFO.template"

# 3. Optionally pin the OpenClaw image tag in the bundled compose file.
if [ "$IMAGE_TAG" != "latest" ]; then
    sed -i.bak -e "s|openclaw:latest|openclaw:$IMAGE_TAG|g" \
        "$STAGE/package/openclaw/compose.yml"
    rm -f "$STAGE/package/openclaw/compose.yml.bak"
fi

# 4. Pack package/ into package.tgz at the staging root.
#    package.tgz itself is what DSM extracts into $SYNOPKG_PKGDEST.
(cd "$STAGE/package" && tar \
    --format=gnutar \
    --uid 0 --gid 0 --uname root --gname root \
    -czf "$STAGE/package.tgz" \
    $(ls -A))
rm -rf "$STAGE/package"

# 4b. Append checksum (MD5 of package.tgz) to INFO — DSM validates this.
PKG_MD5=$(md5 -q "$STAGE/package.tgz" 2>/dev/null || md5sum "$STAGE/package.tgz" | awk '{print $1}')
echo "checksum=\"$PKG_MD5\"" >> "$STAGE/INFO"

# 5. Strip macOS .DS_Store anywhere under the stage.
find "$STAGE" -name ".DS_Store" -delete

# 6. Make scripts executable.
chmod 755 "$STAGE/scripts/"*

# 7. Empty signature file — DSM accepts an empty/missing one for unsigned
#    packages; including it matches the shape of official packages.
: > "$STAGE/syno_signature.asc"

# 8. Tar everything into the .spk with an explicit file list (no "./" prefix),
#    GNU-format, root:root ownership. Order matches Synology's own packages:
#    package.tgz first, then INFO, scripts, conf, icons, etc. DSM has been
#    observed to reject archives where package.tgz isn't near the top.
ENTRIES="package.tgz INFO"
for d in scripts conf WIZARD_UIFILES; do
    [ -d "$STAGE/$d" ] && ENTRIES="$ENTRIES $d"
done
ENTRIES="$ENTRIES PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG syno_signature.asc"

(cd "$STAGE" && tar \
    --format=gnutar \
    --uid 0 --gid 0 --uname root --gname root \
    -cf "$OUT" \
    $ENTRIES)

SIZE=$(wc -c < "$OUT" | tr -d ' ')
SHA256=$(shasum -a 256 "$OUT" | awk '{print $1}')

printf '\nBuilt: %s\n  version: %s\n  image:   ghcr.io/openclaw/openclaw:%s\n  size:    %s bytes\n  sha256:  %s\n' \
    "$OUT" "$VERSION" "$IMAGE_TAG" "$SIZE" "$SHA256"
