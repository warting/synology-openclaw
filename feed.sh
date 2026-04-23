#!/bin/sh
# Regenerate feed/packages.json from this repo's published GitHub Releases.
#
# Each Release that has an .spk asset becomes one entry in the feed. The most
# recently published release wins if two releases share a version.
#
# Runs either locally (requires gh auth) or in CI (uses $GITHUB_TOKEN).
# Writes to stdout; the CI job redirects into feed/packages.json.
set -eu

REPO="${REPO:-warting/synology-openclaw}"
FEED_BASE="${FEED_BASE:-https://warting.github.io/synology-openclaw}"

# Prefer gh CLI when available; fall back to curl+GITHUB_TOKEN in CI.
fetch_releases() {
    if command -v gh >/dev/null 2>&1; then
        gh api "repos/$REPO/releases" --paginate
    else
        curl -fsSL -H "Accept: application/vnd.github+json" \
            ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
            "https://api.github.com/repos/$REPO/releases?per_page=100"
    fi
}

releases_json="$(fetch_releases)"

# Extract .spk assets: version, download URL, size, sha256 (computed by
# downloading the asset — releases are small enough and feed.sh runs rarely).
packages_json="$(
    echo "$releases_json" | jq -c '
        map(
            . as $rel |
            (.assets // [])
            | map(select(.name | endswith(".spk")))
            | map({
                version: ($rel.tag_name | ltrimstr("v")),
                name: .name,
                url: .browser_download_url,
                size: .size
            })
        )
        | add // []
        | unique_by(.version)
    '
)"

emit_package() {
    version="$1"
    name="$2"
    url="$3"
    size="$4"

    tmpfile="$(mktemp)"
    curl -fsSL -o "$tmpfile" "$url"
    md5="$(md5sum "$tmpfile" 2>/dev/null | awk '{print $1}' || md5 -q "$tmpfile")"
    sha256="$(shasum -a 256 "$tmpfile" | awk '{print $1}')"
    rm -f "$tmpfile"

    jq -n \
        --arg version "$version" \
        --arg url "$url" \
        --arg md5 "$md5" \
        --arg sha256 "$sha256" \
        --argjson size "$size" \
        --arg feed_base "$FEED_BASE" \
        '{
            package: "openclaw",
            version: $version,
            dname: "OpenClaw",
            desc: "Self-hosted OpenClaw AI agent. Optional Ollama integration.",
            maintainer: "warting",
            maintainer_url: "https://github.com/warting/synology-openclaw",
            distributor: "warting",
            distributor_url: "https://github.com/warting/synology-openclaw",
            thumbnail: [
                ($feed_base + "/icon_72.png"),
                ($feed_base + "/icon_256.png")
            ],
            snapshot: [],
            qinst: true,
            qstart: true,
            qupgrade: true,
            start: true,
            beta: false,
            link: $url,
            size: $size,
            md5: $md5,
            sha256: $sha256
        }'
}

entries="[]"
echo "$packages_json" | jq -c '.[]' | while read -r pkg; do
    version=$(echo "$pkg" | jq -r '.version')
    name=$(echo "$pkg" | jq -r '.name')
    url=$(echo "$pkg" | jq -r '.url')
    size=$(echo "$pkg" | jq -r '.size')
    entry="$(emit_package "$version" "$name" "$url" "$size")"
    entries="$(echo "$entries" | jq --argjson e "$entry" '. + [$e]')"
    echo "$entries" > /tmp/openclaw-feed-entries.json
done

# Read back the accumulated entries (while-loop runs in subshell on some shells).
final_entries="$(cat /tmp/openclaw-feed-entries.json 2>/dev/null || echo '[]')"
rm -f /tmp/openclaw-feed-entries.json

jq -n --argjson packages "$final_entries" '{packages: $packages}'
