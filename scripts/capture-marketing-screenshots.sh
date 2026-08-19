#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XCODE_APP="${XCODE_APP:-/Applications/Xcode-beta.app}"
DEVELOPER_DIR="$XCODE_APP/Contents/Developer"
SIMCTL="$DEVELOPER_DIR/usr/bin/simctl"
XCODEBUILD="$DEVELOPER_DIR/usr/bin/xcodebuild"
OUTPUT_DIR="$ROOT_DIR/Marketing/Screenshots"
IPAD_UDID="${IPAD_UDID:-B718C475-E5CE-45C4-8B43-4E9F39657CE7}"
BUNDLE_ID="dev.local.iPadMirrorPad"
MAC_APP_NAME="iPad Mirror Mac"
MAC_PROCESS_NAME="iPadMirrorMac"
MAC_WINDOW_WIDTH=1280
MAC_WINDOW_HEIGHT=800

export DEVELOPER_DIR

mkdir -p "$OUTPUT_DIR/ko" "$OUTPUT_DIR/en"

echo "==> Build Mac app"
"$ROOT_DIR/scripts/package-mac-app.sh" release >/dev/null
MAC_APP="$ROOT_DIR/.build/release/iPad Mirror Mac.app"
rm -rf "/Applications/$MAC_APP_NAME.app"
cp -R "$MAC_APP" "/Applications/$MAC_APP_NAME.app"

echo "==> Build iPad app (screenshot configuration)"
python3 "$ROOT_DIR/scripts/strip-admob-for-screenshots.py" strip
PLIST="$ROOT_DIR/Sources/iPadMirrorPad/Info.plist"
PLIST_BAK="$PLIST.screenshot-build-bak"
cp "$PLIST" "$PLIST_BAK"
/usr/libexec/PlistBuddy -c "Delete :GADApplicationIdentifier" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :NSUserTrackingUsageDescription" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Delete :SKAdNetworkItems" "$PLIST" 2>/dev/null || true
restore_ipad_project() {
  python3 "$ROOT_DIR/scripts/strip-admob-for-screenshots.py" restore
  if [[ -f "$PLIST_BAK" ]]; then
    mv "$PLIST_BAK" "$PLIST"
  fi
}
trap restore_ipad_project EXIT
"$XCODEBUILD" \
  -resolvePackageDependencies \
  -project "$ROOT_DIR/iPadMirrorPad.xcodeproj" \
  -scheme iPadMirrorPad >/dev/null
"$XCODEBUILD" \
  -project "$ROOT_DIR/iPadMirrorPad.xcodeproj" \
  -scheme iPadMirrorPad \
  -destination "platform=iOS Simulator,id=$IPAD_UDID" \
  -configuration Debug \
  OTHER_SWIFT_FLAGS='$(inherited) -D SCREENSHOT_DEMO' \
  build >/dev/null

IPAD_APP="$(ls -d "$HOME"/Library/Developer/Xcode/DerivedData/iPadMirrorPad-*/Build/Products/Debug-iphonesimulator/iPadMirrorPad.app | tail -1)"

capture_ipad() {
  local locale="$1"
  local output="$2"
  echo "==> iPad screenshot ($locale)"
  "$SIMCTL" boot "$IPAD_UDID" 2>/dev/null || true
  "$SIMCTL" uninstall "$IPAD_UDID" "$BUNDLE_ID" 2>/dev/null || true
  "$SIMCTL" install "$IPAD_UDID" "$IPAD_APP"
  "$SIMCTL" terminate "$IPAD_UDID" "$BUNDLE_ID" 2>/dev/null || true
  "$SIMCTL" launch "$IPAD_UDID" "$BUNDLE_ID" -ScreenshotDemo -ScreenshotLocale "$locale" -SkipAds >/dev/null
  sleep 5
  "$SIMCTL" io "$IPAD_UDID" screenshot "$output"
}

capture_mac() {
  local locale="$1"
  local output="$2"
  echo "==> Mac screenshot ($locale)"
  osascript -e "tell application \"$MAC_APP_NAME\" to quit" >/dev/null 2>&1 || true
  sleep 1
  open -a "/Applications/$MAC_APP_NAME.app" --args -ScreenshotDemo -ScreenshotLocale "$locale" -SkipAds
  sleep 4
  local bounds
  bounds="$(osascript <<EOF
tell application "$MAC_APP_NAME" to activate
delay 1
tell application "System Events"
  tell process "$MAC_PROCESS_NAME"
    set frontmost to true
    set size of window 1 to {$MAC_WINDOW_WIDTH, $MAC_WINDOW_HEIGHT}
    set position of window 1 to {120, 80}
    delay 0.5
    set p to position of window 1
    set s to size of window 1
    return (item 1 of p as text) & "," & (item 2 of p as text) & "," & (item 1 of s as text) & "," & (item 2 of s as text)
  end tell
end tell
EOF
)"
  screencapture -x -R"$bounds" "$output"
}

capture_ipad ko "$OUTPUT_DIR/ko/ipad-01-main.png"
capture_ipad en "$OUTPUT_DIR/en/ipad-01-main.png"
capture_mac ko "$OUTPUT_DIR/ko/mac-01-mirror.png"
capture_mac en "$OUTPUT_DIR/en/mac-01-mirror.png"

echo "완료:"
find "$OUTPUT_DIR" -name '*.png' | sort
