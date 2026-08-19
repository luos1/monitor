#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

ARCHIVE_PATH="$ROOT_DIR/.build/iPadMirrorPad.xcarchive"
EXPORT_PATH="$ROOT_DIR/.build/export"

rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

echo "==> Archive"
xcodebuild \
  -project "$ROOT_DIR/iPadMirrorPad.xcodeproj" \
  -scheme iPadMirrorPad \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

echo "==> Export IPA"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$ROOT_DIR/Packaging/ExportOptions-export.plist" \
  -allowProvisioningUpdates

echo "==> Upload (requires stable Xcode SDK or API key auth)"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$ROOT_DIR/.build/upload" \
  -exportOptionsPlist "$ROOT_DIR/Packaging/ExportOptions.plist" \
  -allowProvisioningUpdates

echo "Done: $EXPORT_PATH/iPadMirrorPad.ipa"
