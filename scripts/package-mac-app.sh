#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
PRODUCT="iPadMirrorMac"
APP_NAME="아이패드미러.app"
BUNDLE_DIR=".build/${CONFIGURATION}/${APP_NAME}"
EXECUTABLE_PATH=".build/${CONFIGURATION}/${PRODUCT}"

swift build --configuration "$CONFIGURATION"

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

if [[ ! -f Packaging/AppIcon.icns ]]; then
  python3 scripts/generate-mac-icon.py
fi

cp Packaging/Info.plist "$BUNDLE_DIR/Contents/Info.plist"
cp Packaging/AppIcon.icns "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
cp Packaging/PrivacyInfo.xcprivacy "$BUNDLE_DIR/Contents/Resources/PrivacyInfo.xcprivacy"
cp "$EXECUTABLE_PATH" "$BUNDLE_DIR/Contents/MacOS/$PRODUCT"
chmod +x "$BUNDLE_DIR/Contents/MacOS/$PRODUCT"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign \
    --force \
    --options runtime \
    --timestamp \
    --sign "$CODESIGN_IDENTITY" \
    "$BUNDLE_DIR"
fi

printf '%s\n' "$BUNDLE_DIR"
