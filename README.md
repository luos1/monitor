# 아이패드미러

iPhone/iPad의 현재 화면을 Mac으로 보내는 미러링 앱입니다. iOS 17+ 송신 앱과 macOS 14+ 수신 앱을 함께 써야 동작합니다. Mac App Store 빌드는 같은 접근 가능한 로컬 네트워크를 사용합니다.

## 제출 상태

2026-10-09 18:49 KST(09:49 UTC)에 App Store Connect에서 확인한 기록입니다.

| 앱 | 재제출한 버전·빌드 | 당시 심사 상태 | 출시 방식 |
| --- | --- | --- | --- |
| iOS | 1.0(13) | Waiting for Review | 수동 출시 |
| Mac App Store | 1.0(3) | Waiting for Review | 수동 출시 |

양쪽 재제출은 완료됐지만, 이 기록은 현재 승인·공개 완료를 뜻하지 않습니다. 심사자가 동반 앱을 설치할 수 있는 경로도 아직 확인되지 않았습니다. [검증 범위와 남은 단계](docs/LAUNCH.md)를 확인하세요.

기존 공개 USB Mac **1.0.0(4)**는 별도 직접 배포본입니다. 개발 옵션 토큰이 남아 있어 새 Store **1.0(3)** 수정본이나 동등한 설치 파일로 안내할 수 없습니다. [Mac 배포 방식과 제한](docs/MAC-APP-STORE.md)에 구분해 기록했습니다.

## 구성

| 대상 | 역할 | 위치 |
| --- | --- | --- |
| iPhone/iPad 앱 | 화면을 보냄 | `Sources/iPadMirrorPad` |
| Broadcast Extension | 홈/다른 앱 포함 전체 화면 방송 | `Sources/iPadMirrorBroadcastExtension` |
| Mac 앱 | 화면을 받아 표시 | `Sources/iPadMirrorMac` |
| 공유 | 사용 시간, 테마, 스토어 링크 | `Sources/iPadMirrorShared` |

## 사용 순서

1. iPhone/iPad와 Mac을 같은 접근 가능한 로컬 네트워크에 연결하고, 두 앱의 로컬 네트워크 접근을 허용합니다.
2. Mac에서 아이패드미러를 켭니다.
3. iPhone/iPad에서 **전체 화면 공유 시작**을 누르고 `아이패드미러 방송`을 선택한 뒤 시스템의 방송 시작을 확인합니다.
4. 송신 기기에 표시된 8자리 연결 코드를 Mac에 입력한 뒤 왼쪽 목록에서 기기 이름을 선택합니다.

## 무료 / 유료

- Mac 수신 앱: 시간 제한과 별도 구매 없이 무료
- iPad 송신 앱: 기본 사용 60분
- iPad에서 AdMob 리워드 광고를 보면 60분 연장, 홈 화면에 배너 표시
- 영구 사용 `$4.99`, 개발자 응원 `$99.99` (StoreKit, 응원 시 영구 사용도 해제)
- 설정: `Sources/iPadMirrorShared/MonetizationConfig.swift`, 안내: `docs/MONETIZATION.md`

## 빌드

아래 Mac 명령은 개발·직접 배포용입니다. Mac App Store 패키징은 [별도 안내](docs/MAC-APP-STORE.md)를 사용합니다. 커밋된 iOS 기본 빌드 번호 7과 실제 제출 IPA 13의 차이는 [출시 검증](docs/LAUNCH.md)에 기록했습니다.

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

## 공개 전 남은 검증

- 새 제출 빌드에 맞는 심사자의 동반 앱 설치 경로
- 실제 iPhone/iPad + Mac Store 빌드의 네트워크 미러링·회전·방송 종료·재연결
- 실제 광고·UMP/ATT와 Apple Sandbox 구매·복원
- 새 빌드와 일치하는 연결 화면·스크린샷·스토어 안내, 승인 및 수동 출시 결과
