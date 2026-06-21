#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-debug}"
PRODUCT="iPadMirrorMac"
APP_NAME="iPad Mirror Mac.app"
BUNDLE_DIR=".build/${CONFIGURATION}/${APP_NAME}"
EXECUTABLE_PATH=".build/${CONFIGURATION}/${PRODUCT}"

swift build --configuration "$CONFIGURATION"

rm -rf "$BUNDLE_DIR"
mkdir -p "$BUNDLE_DIR/Contents/MacOS"
cp Packaging/Info.plist "$BUNDLE_DIR/Contents/Info.plist"
cp "$EXECUTABLE_PATH" "$BUNDLE_DIR/Contents/MacOS/$PRODUCT"
chmod +x "$BUNDLE_DIR/Contents/MacOS/$PRODUCT"

printf '%s\n' "$BUNDLE_DIR"
