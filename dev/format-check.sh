#!/bin/sh
# Local sanity-check the repo before committing or building.
# Mirrors a subset of what CI does.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "-- jq lint"
for f in src/WIZARD_UIFILES/* feed/packages.json src/conf/privilege src/conf/resource src/package/ui/config; do
    echo "   $f"
    jq . "$f" >/dev/null
done

echo "-- shellcheck"
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck src/scripts/* build.sh feed.sh dev/format-check.sh
else
    echo "   (shellcheck not installed — skipping)"
fi

echo "-- INFO.template has required fields"
for field in package version displayname description arch maintainer os_min_ver; do
    grep -q "^${field}=" src/INFO.template || {
        echo "   MISSING in INFO.template: $field" >&2
        exit 1
    }
done

echo "OK"
