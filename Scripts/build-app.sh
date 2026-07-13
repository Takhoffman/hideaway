#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
BUILD_NUMBER="${2:-1}"
APP="$ROOT/dist/Hideaway.app"
CONTENTS="$APP/Contents"

cd "$ROOT"
swift build --configuration release --arch arm64 --arch x86_64
BIN_DIR="$(swift build --configuration release --arch arm64 --arch x86_64 --show-bin-path)"
SPARKLE_FRAMEWORK="$(find "$ROOT/.build/artifacts" -type d -name Sparkle.framework -print -quit)"

if [[ -z "$SPARKLE_FRAMEWORK" ]]; then
    echo "Sparkle.framework was not found. Run 'swift package resolve' and try again." >&2
    exit 1
fi

rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Frameworks" "$CONTENTS/Resources"
install -m 755 "$BIN_DIR/Hideaway" "$CONTENTS/MacOS/Hideaway"
install -m 644 "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
ditto "$SPARKLE_FRAMEWORK" "$CONTENTS/Frameworks/Sparkle.framework"
install_name_tool -add_rpath "@executable_path/../Frameworks" "$CONTENTS/MacOS/Hideaway"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$CONTENTS/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$CONTENTS/Info.plist"

ICON_WORK="$(mktemp -d)"
trap 'rm -rf "$ICON_WORK"' EXIT
ICONSET="$ICON_WORK/AppIcon.iconset"
mkdir -p "$ICONSET"

for SIZE in 16 32 128 256 512; do
    sips -z "$SIZE" "$SIZE" "$ROOT/Assets/AppIcon-v2.png" --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null
    DOUBLE=$((SIZE * 2))
    sips -z "$DOUBLE" "$DOUBLE" "$ROOT/Assets/AppIcon-v2.png" --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$CONTENTS/Resources/AppIcon.icns"

SIGN_IDENTITY="${CODE_SIGN_IDENTITY:--}"
SPARKLE="$CONTENTS/Frameworks/Sparkle.framework"
SPARKLE_VERSION="$SPARKLE/Versions/B"

if [[ "$SIGN_IDENTITY" == "-" ]]; then
    # An ad-hoc identity cannot satisfy hardened-runtime library validation
    # for Sparkle's separately signed framework. Keep Sparkle's vendor
    # signatures intact and sign only the host app for local/CI builds.
    codesign --force --sign "$SIGN_IDENTITY" "$APP"
else
    # Sparkle's documented manual distribution signing order. Do not use
    # --deep here; Downloader.xpc has component-specific entitlements.
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$SPARKLE_VERSION/XPCServices/Installer.xpc"
    codesign --force --options runtime --preserve-metadata=entitlements \
        --sign "$SIGN_IDENTITY" "$SPARKLE_VERSION/XPCServices/Downloader.xpc"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$SPARKLE_VERSION/Autoupdate"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$SPARKLE_VERSION/Updater.app"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$SPARKLE"
    codesign --force --options runtime --sign "$SIGN_IDENTITY" "$APP"
fi
codesign --verify --deep --strict --verbose=2 "$APP"

echo "$APP"
