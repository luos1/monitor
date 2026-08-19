#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_APP="${XCODE_APP:-/Applications/Xcode_26.6.app}"
export DEVELOPER_DIR="$XCODE_APP/Contents/Developer"

API_KEY_ID="${APP_STORE_CONNECT_KEY_ID:-MM725G8UMZ}"
API_ISSUER="${APP_STORE_CONNECT_ISSUER_ID:-646ee8fb-88fc-42b0-bf85-51c7a44d67bc}"
KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-$HOME/Downloads/AuthKey_${API_KEY_ID}.p8}"

ARCHIVE_PATH="$ROOT_DIR/.build/iPadMirrorPad.xcarchive"
EXPORT_PATH="$ROOT_DIR/.build/export"

if [[ ! -d "$XCODE_APP" ]]; then
  echo "Stable Xcode not found at $XCODE_APP"
  exit 1
fi

if [[ ! -f "$KEY_PATH" ]]; then
  echo "API key not found at $KEY_PATH"
  exit 1
fi

mkdir -p "$ROOT_DIR/.build"

echo "==> Archive with $XCODE_APP"
xcodebuild \
  -project "$ROOT_DIR/iPadMirrorPad.xcodeproj" \
  -scheme iPadMirrorPad \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  -allowProvisioningUpdates \
  archive

echo "==> Export IPA"
rm -rf "$EXPORT_PATH"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$ROOT_DIR/Packaging/ExportOptions-export.plist" \
  -allowProvisioningUpdates

mkdir -p "$HOME/.appstoreconnect/private_keys"
cp "$KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"

echo "==> Upload to App Store Connect"
xcrun altool --upload-app \
  -f "$EXPORT_PATH/iPadMirrorPad.ipa" \
  -t ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER"

echo "Done."
