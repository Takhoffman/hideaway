#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Usage: Scripts/release.sh <major.minor.patch>" >&2
    exit 1
fi

cd "$ROOT"

if [[ "$(git branch --show-current)" != "main" ]]; then
    echo "Releases must be created from main." >&2
    exit 1
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
    echo "Commit or stash all changes before releasing." >&2
    exit 1
fi

TAG="v$VERSION"
if git rev-parse "$TAG" >/dev/null 2>&1; then
    echo "Tag $TAG already exists." >&2
    exit 1
fi

BUILD_NUMBER="$(date -u +%Y%m%d%H%M)"
"$ROOT/Scripts/build-app.sh" "$VERSION" "$BUILD_NUMBER"

RELEASE_DIR="$(mktemp -d)"
trap 'rm -rf "$RELEASE_DIR"' EXIT
ARCHIVE="$RELEASE_DIR/Hideaway-$VERSION.zip"

ditto -c -k --sequesterRsrc --keepParent "$ROOT/dist/Hideaway.app" "$ARCHIVE"
cp "$ROOT/updates/appcast.xml" "$RELEASE_DIR/appcast.xml"

"$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --account com.takhoffman.hideaway \
    --download-url-prefix "https://github.com/Takhoffman/hideaway/releases/download/$TAG/" \
    --link "https://github.com/Takhoffman/hideaway" \
    --maximum-versions 5 \
    -o "$RELEASE_DIR/appcast.xml" \
    "$RELEASE_DIR"

git tag -a "$TAG" -m "Hideaway $VERSION"
git push origin "$TAG"
gh release create "$TAG" "$ARCHIVE" \
    --repo Takhoffman/hideaway \
    --title "Hideaway $VERSION" \
    --generate-notes \
    --verify-tag

cp "$RELEASE_DIR/appcast.xml" "$ROOT/updates/appcast.xml"
git add updates/appcast.xml
git commit -m "Update appcast for $TAG"
git push origin main

echo "Published https://github.com/Takhoffman/hideaway/releases/tag/$TAG"
