#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -d /Applications/Xcode_26.3.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode_26.3.app/Contents/Developer
elif [[ -d /Applications/Xcode_26.6.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode_26.6.app/Contents/Developer
fi

API_KEY_ID="${APP_STORE_CONNECT_KEY_ID:?}"
API_ISSUER="${APP_STORE_CONNECT_ISSUER_ID:?}"
KEY_PATH="${APP_STORE_CONNECT_KEY_PATH:-$RUNNER_TEMP/AuthKey.p8}"

if [[ -n "${APP_STORE_CONNECT_KEY_BASE64:-}" ]]; then
  echo "$APP_STORE_CONNECT_KEY_BASE64" | base64 --decode > "$KEY_PATH"
fi

mkdir -p "$HOME/.appstoreconnect/private_keys"
cp "$KEY_PATH" "$HOME/.appstoreconnect/private_keys/AuthKey_${API_KEY_ID}.p8"

xcodebuild \
  -project "$ROOT_DIR/iPadMirrorPad.xcodeproj" \
  -scheme iPadMirrorPad \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath "${ARCHIVE_PATH:-$RUNNER_TEMP/iPadMirrorPad.xcarchive}" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM:-2YRYWKZ3M3}" \
  archive

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH:-$RUNNER_TEMP/iPadMirrorPad.xcarchive}" \
  -exportPath "${EXPORT_PATH:-$RUNNER_TEMP/export}" \
  -exportOptionsPlist "$ROOT_DIR/Packaging/ExportOptions-export.plist" \
  -allowProvisioningUpdates

xcrun altool --upload-app \
  -f "${EXPORT_PATH:-$RUNNER_TEMP/export}/iPadMirrorPad.ipa" \
  -t ios \
  --apiKey "$API_KEY_ID" \
  --apiIssuer "$API_ISSUER"
