# 아이패드미러

iPad 현재 화면을 같은 네트워크(또는 USB)의 Mac으로 보내는 미러링 앱입니다. iPad 앱과 Mac 앱을 함께 써야 동작합니다.

## 구성

| 대상 | 역할 | 위치 |
| --- | --- | --- |
| iPad 앱 | 화면을 보냄 | `Sources/iPadMirrorPad` |
| Broadcast Extension | 홈/다른 앱 포함 전체 화면 방송 | `Sources/iPadMirrorBroadcastExtension` |
| Mac 앱 | 화면을 받아 표시 | `Sources/iPadMirrorMac` |
| 공유 | 사용 시간, 테마, 스토어 링크 | `Sources/iPadMirrorShared` |

## 사용 순서

1. Mac에서 아이패드미러를 켭니다.
2. iPad에서 **전체 화면 공유 시작**을 누르고 `아이패드미러 방송`을 선택합니다.
3. Mac 왼쪽 목록에서 iPad 이름을 선택합니다.

## 무료 / 유료

- 기본 사용 60분
- iPad에서 AdMob 리워드 광고를 보면 60분 연장, 홈 화면에 배너 표시
- 영구 사용 `$4.99`, 개발자 응원 `$99.99` (StoreKit, 응원 시 영구 사용도 해제)
- 설정: `Sources/iPadMirrorShared/MonetizationConfig.swift`, 안내: `docs/MONETIZATION.md`

## 빌드

```bash
# Mac 앱
swift test
./scripts/package-mac-app.sh release

# 직접 배포용 Developer ID 서명 + Hardened Runtime
CODESIGN_IDENTITY="Developer ID Application: 이름 (TEAMID)" \
  ./scripts/package-mac-app.sh release

# iPad 앱
# Xcode에서 iPadMirrorPad.xcodeproj 를 열고 iPad에 설치
```

## 디자인

UI는 Google Stitch 워크플로로 정리했습니다.

- 토큰과 규칙: `.stitch/DESIGN.md`
- HTML 목업: `docs/stitch/index.html`
- 출시 체크리스트: `docs/LAUNCH.md`
- 스토어 문구: `docs/APP_STORE.md`
- 개인정보 처리방침: `docs/PRIVACY.md`

## 출시 전 필수

- App Store Connect / Mac 배포용 번들 ID와 서명
- `StoreLinks.swift`에 동반 앱, IAP, 도네이션, 개인정보 처리방침 URL
- 실제 기기에서 iPad+Mac 페어 테스트
- 스크린샷과 개인정보 처리방침 호스팅
