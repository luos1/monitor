#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOTS_DIR="$ROOT_DIR/Marketing/Screenshots"
APP_ID="${APP_ID:-}"
VERSION_ID="${VERSION_ID:-}"
MAC_APP_ID="${MAC_APP_ID:-}"
MAC_VERSION_ID="${MAC_VERSION_ID:-}"

if ! command -v asccli >/dev/null; then
  echo "asccli가 필요합니다: brew install asccli"
  exit 1
fi

if ! asccli auth check >/dev/null 2>&1; then
  cat <<'EOF'
App Store Connect API 키가 설정되어 있지 않습니다.

1. App Store Connect → Users and Access → Integrations → App Store Connect API
2. 키 생성 후 아래 명령 실행:

asccli auth login \
  --key-id "YOUR_KEY_ID" \
  --issuer-id "YOUR_ISSUER_ID" \
  --private-key-path "/path/to/AuthKey_XXXXXX.p8"

환경 변수:
  APP_ID          iPad 앱 App Store Connect app id
  VERSION_ID      업로드할 App Store version id
  MAC_APP_ID      Mac 앱 app id (선택)
  MAC_VERSION_ID  Mac 앱 version id (선택)
EOF
  exit 1
fi

upload_locale() {
  local app_id="$1"
  local version_id="$2"
  local locale="$3"
  local device_type="$4"
  local file="$5"

  local localization_id
  localization_id="$(asccli version-localizations list --version-id "$version_id" --output json \
    | python3 -c "import json,sys; loc=sys.argv[1]; data=json.load(sys.stdin).get('data',[]); print(next(item['id'] for item in data if item.get('attributes',{}).get('locale')==loc))" "$locale")"

  local set_id
  set_id="$(asccli screenshot-sets list --localization-id "$localization_id" --output json \
    | python3 -c "import json,sys; target=sys.argv[1]; data=json.load(sys.stdin).get('data',[]); print(next(item['id'] for item in data if item.get('attributes',{}).get('screenshotDisplayType')==target))" "$device_type")"

  echo "==> Upload $file ($locale / $device_type)"
  asccli screenshots upload --set-id "$set_id" --file "$file"
}

if [[ -z "$APP_ID" || -z "$VERSION_ID" ]]; then
  echo "APP_ID, VERSION_ID 환경 변수를 설정하세요."
  echo "앱 목록: asccli apps list"
  echo "버전 목록: asccli versions list --app APP_ID"
  exit 1
fi

upload_locale "$APP_ID" "$VERSION_ID" "ko" "APP_IPAD_PRO_3GEN_129" "$SCREENSHOTS_DIR/ko/ipad-01-main.png"
upload_locale "$APP_ID" "$VERSION_ID" "en-US" "APP_IPAD_PRO_3GEN_129" "$SCREENSHOTS_DIR/en/ipad-01-main.png"

if [[ -n "$MAC_APP_ID" && -n "$MAC_VERSION_ID" ]]; then
  upload_locale "$MAC_APP_ID" "$MAC_VERSION_ID" "ko" "APP_DESKTOP" "$SCREENSHOTS_DIR/ko/mac-01-mirror.png"
  upload_locale "$MAC_APP_ID" "$MAC_VERSION_ID" "en-US" "APP_DESKTOP" "$SCREENSHOTS_DIR/en/mac-01-mirror.png"
fi

echo "App Store Connect 스크린샷 업로드 완료"
