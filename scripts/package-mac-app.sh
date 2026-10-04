#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
case "$CONFIGURATION" in
  debug|release) ;;
  *) printf 'Usage: %s [debug|release]\n' "$0" >&2; exit 2 ;;
esac

cd "$(cd -- "$(dirname -- "$0")/.." && pwd)"
BUILD_ARGS=(--configuration "$CONFIGURATION")
if [[ "$CONFIGURATION" == "release" ]]; then
  BUILD_ARGS+=(--arch arm64 --arch x86_64)
fi
if [[ -n "${IPADMIRROR_BUILD_ROOT:-}" ]]; then
  BUILD_ARGS+=(--scratch-path "$IPADMIRROR_BUILD_ROOT")
fi
PRODUCT="iPadMirrorMac"
APP_NAME="iPad Mirror.app"

swift build "${BUILD_ARGS[@]}"
BIN_DIR="$(swift build "${BUILD_ARGS[@]}" --show-bin-path)"
BUNDLE_DIR="$BIN_DIR/$APP_NAME"
EXECUTABLE_PATH="$BIN_DIR/$PRODUCT"

[[ -f "$EXECUTABLE_PATH" ]] || { printf 'Missing executable: %s\n' "$EXECUTABLE_PATH" >&2; exit 1; }

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

if [[ ! -f Packaging/AppIcon.icns ]]; then
  python3 scripts/generate-mac-icon.py
fi

cp Packaging/Info.plist "$BUNDLE_DIR/Contents/Info.plist"
cp Packaging/AppIcon.icns "$BUNDLE_DIR/Contents/Resources/AppIcon.icns"
cp Packaging/PrivacyInfo.xcprivacy "$BUNDLE_DIR/Contents/Resources/PrivacyInfo.xcprivacy"
cp -R "$BIN_DIR/iPadMirrorMac_iPadMirrorShared.bundle" "$BUNDLE_DIR/Contents/Resources/"
cp -R Packaging/en.lproj Packaging/ko.lproj "$BUNDLE_DIR/Contents/Resources/"
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
