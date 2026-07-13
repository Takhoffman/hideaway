#!/bin/bash

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-0.1.0}"
BUILD_NUMBER="${2:-1}"
ARCHIVE="$ROOT/dist/Hideaway.xcarchive"
APP="$ROOT/dist/Hideaway.app"
SIGN_IDENTITY="${CODE_SIGN_IDENTITY:-Developer ID Application}"

cd "$ROOT"

rm -rf "$ARCHIVE" "$APP"

xcodebuild archive \
    -project "$ROOT/Hideaway.xcodeproj" \
    -scheme Hideaway \
    -configuration Release \
    -archivePath "$ARCHIVE" \
    -destination "generic/platform=macOS" \
    -derivedDataPath "$ROOT/.build/xcode-derived-data" \
    MARKETING_VERSION="$VERSION" \
    CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
    CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
    DEVELOPMENT_TEAM=KF4GF4J4K9 \
    ARCHS="arm64 x86_64" \
    ONLY_ACTIVE_ARCH=NO

ditto "$ARCHIVE/Products/Applications/Hideaway.app" "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type execute --verbose=2 "$APP" || true

echo "$APP"
