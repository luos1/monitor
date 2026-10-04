# 아이패드미러 출시 준비

검증 기준: 2026-10-04. MacBook 원본 저장소에서 개발하며 동기화 사본과 다른 제품은 수정하지 않습니다.

## 확인한 범위

- macOS 14+ 수신 앱과 iOS 17+ 송신 앱/Broadcast Extension이 빌드됩니다.
- Google Mobile Ads 12.14.0, UMP 3.1.0이 고정되어 있습니다. Debug는 Google 테스트 광고 ID, Release는 기존 운영 ID입니다.
- 광고는 UMP의 `canRequestAds` 이후에 요청합니다. 필요한 경우 개인정보 설정을 다시 여는 버튼이 표시됩니다. `-SkipAds` 실행은 광고와 추적 요청을 건너뜁니다.
- 보상 콜백 이후에만 리워드를 지급합니다. 표시 실패 시 버튼을 복구하고 개인정보 권한 변경/영구 사용 인증 시 이전 광고 로드 결과를 버립니다.
- StoreKit 검증 결과가 있는 현재 entitlement만 사용합니다. 취소·환불/만료/대체된 거래와 다른 상품은 영구 사용 권한을 부여하지 않습니다.
- 단위 테스트 11개 통과: 페어링/암호화, 사용 시간/보상 저장, 영구 사용 권한 정책. 실기기 방송과 StoreKit 구매 검증을 대신하지 않습니다.
- App Group UserDefaults 사유는 앱에 `CA92.1`/`1C8F.1`, 확장에 `1C8F.1`입니다. [Apple 공식 목록](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)을 실제 저장소 사용에 맞췄습니다.
- 앱/확장 버전과 빌드는 Xcode 설정에서 읽습니다. 기본값은 버전 1.0, 빌드 2입니다. 기존 App Store 빌드 1과 구분합니다.
- Mac 패키징은 SwiftPM이 반환하는 실행 파일 위치를 사용합니다. `IPADMIRROR_BUILD_ROOT`로 임시 빌드 폴더를 지정할 수 있습니다.

## 기존 등록 상태와 남은 작업

2026-10-03 기존 계정/API 확인 결과입니다. 외부 상태는 제출 직전에 다시 확인합니다.

| 항목 | 확인 결과 | 남은 작업 |
| --- | --- | --- |
| App Store 앱 | 기존 `com.raccoonmerchant.ipadmirror` 존재 | 기존 버전 편집, 중복 앱 생성 금지 |
| 버전 1.0 | `PREPARE_FOR_SUBMISSION` | 신규 검증 빌드 선택 후 제출 |
| 기존 빌드 1 | 처리 `VALID` | 이번 수정 소스로 만든 빌드와 구분 |
| IAP 두 개 | Non-Consumable, `MISSING_METADATA` | 심사용 화면, 판매 지역 및 누락 자료 보완 |
| AdMob | 운영 앱/배너/리워드 ID 일치 | 앱 스토어 연결·앱 검토, 결제 계정 확인 |
| UMP | 수동 게시 GDPR 메시지 목록이 비어 있음 | 배포 지역과 실제 개인정보 처리에 맞는 메시지 확인 |
| Mac 배포 | 설치 링크가 비어 있음 | 배포 경로와 검증된 설치 산출물 필요 |
| 실기기 | 실제 iPad 없이 시뮬레이터 실행 확인 | Wi-Fi/USB, 방송 종료/재연결/회전/잘못된 코드 확인 |

## 제출 전 필수 확인

- Mac은 독립된 60분 사용 제한과 StoreKit 권한을 갖고 있습니다. iPad 광고 보상은 iPad App Group에 저장되며 Mac 사용 시간을 늘리지 않습니다. 양쪽 유료 사용 조건과 권한 전달 방식을 확정하고 검증해야 합니다.
- 광고 SDK manifest에는 위치·식별자·광고/이용·진단 정보가 포함됩니다. 기존 `PRIVACY.md`와 App Store 개인정보 응답을 실제 광고 설정 및 데이터 처리에 맞게 확인해야 합니다. 구조 검사로 법적 응답을 확정하지 않습니다.
- 가격, 판매 지역, 연령 등급, 추적/데이터 연결 여부, 수출 관련 응답은 확인된 근거로 작성합니다. 기존 자동 제출 스크립트의 기본값을 그대로 실행하지 않습니다.
- 사용자의 미커밋 AppIcon 변경에는 크기/미할당 이미지 경고가 있습니다. 원본 변경은 보존하며 최종 제출할 아이콘 구성을 확인해야 합니다.
- `python3 scripts/release-preflight.py`, `swift test`, iPad Debug 빌드와 Release archive를 실행합니다. 정확한 소스 해시, 앱/확장 버전·빌드, 서명 및 export 결과와 로그를 보관합니다.
- `.xcarchive` 생성 성공은 IPA 업로드·App Store 처리 완료·심사 제출·승인이 아닙니다. 최종 인계는 명시적으로 선택한 IPA의 SHA-256으로 합니다.

## 로컬 Ruflo

기존 공식 설치를 `scripts/ruflo-local.sh`로 프로젝트 안에서 사용합니다. daemon 자동 시작과 funnel은 꺼져 있으며 다른 프로젝트의 경로 고정 MCP는 재사용하지 않습니다. 메모리 DB와 생성 설정은 Git에서 제외합니다. MCP 초기화/도구 조회/메모리 호출을 확인했으나 Ruflo 정적 품질 분석은 Swift를 분석하지 않으므로 Xcode와 Swift 결과를 사용합니다.
