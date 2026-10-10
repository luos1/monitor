# 2026-10-10 한국어 이름 및 StoreKit 상품 로딩 검증

## 심사에서 확인된 문제

iOS 1.0(13)은 2026-10-10 20:35 KST에 거절됐다. 심사 메시지는 2.1(b)의 인앱 구매 상품 로딩 실패와 5.2.5의 앱 이름·부제에 사용한 iPad/Mac 명칭을 지적했다. 심사 기기는 iPhone 17 Pro Max / iOS 27.0이다.

[심사 메시지 원문](https://appstoreconnect.apple.com/apps/6802445864/appstore/reviewsubmissions/details/fe85de3a-62f2-4363-89de-3e23a8938da3)

제출 IPA와 실제 코드의 상품 ID는 App Store Connect의 `ipadmirror.lifetime` 및 `ipadmirror.donation`과 일치했다. 조회한 두 상품에는 가격·판매 지역, 한국어/영어 현지화, 심사 스크린샷이 있었다. 상태는 Ready to Submit이었다. 조회한 화면에서 필수 정보 누락은 찾지 못했다. 유료 앱 계약의 유효 상태는 확인하지 못했다.

심사 스크린샷의 비활성 구매 버튼과 Loading 표시는 상품이 없는 경우에도 Loading을 반환하던 코드 경로와 일치한다. 이 화면만으로 상품이 비어 나온 서버·계약·sandbox 원인을 확정할 수는 없다. 광고 준비 실패는 별도 표시였다.

## 로컬 수정

- 한국어 앱 표시명과 앱 내 안내를 사용자가 지정한 `스크린미러`로 변경했다. 방송 확장 표시명은 `스크린미러 방송`이다.
- 상품 조회가 종료된 뒤에도 상품이 없으면 현재 이용 불가로 표시한다. 빈 목록 또는 부분 목록은 최대 세 번 재조회하고, 부분 목록에서 누락된 상품을 알린다.
- 구매 화면을 다시 열면 누락된 상품을 재조회한다. 반환된 상품 ID, 누락된 ID 및 조회 오류의 도메인·코드를 진단 로그에 남긴다.
- 구매·복원·권한 검증, 번들 ID·상품 ID·서명 설정·상품 가격·배포 설정은 변경하지 않았다. 영어 앱 이름은 사용자 미지정으로 그대로 두었다.

한국어 콘솔 이름·부제·소개 문구는 [APP_STORE.md](APP_STORE.md)에 있다. 이 검증 기록을 작성할 때 App Store Connect에는 저장하지 못했다. Chrome 연결 시간 초과가 남아 있었다. 콘솔 저장 여부를 로컬 표시명 변경과 구분해야 한다.

## noAccount 진단

처음에는 시뮬레이터 검사에 `CODE_SIGNING_ALLOWED=NO`를 지정했다. 빌드 및 앱 실행은 진행됐지만, 구매 전에 실행하는 `AppTransaction.shared` 환경 검사에서 `StoreKitInternalError.noAccount`가 발생했다. 런타임 로그의 환경은 `Sandbox`였다. 개발자 서명 계정을 찾는 빌드 오류가 아니라, StoreKit 앱 거래 조회에서 발생한 오류다.

Apple의 [AppTransaction.shared 문서](https://developer.apple.com/documentation/storekit/apptransaction/shared)는 앱 거래를 가져올 수 없거나 사용자가 App Store에 인증되지 않은 경우 오류가 발생한다고 설명한다. [StoreKit 환경 선택 설명](https://developer.apple.com/videos/play/wwdc2022/10039/)은 로컬 구성을 선택한 Xcode 환경과 구성을 선택하지 않은 sandbox를 구분한다.

같은 프로젝트·상품 구성·시뮬레이터에서 로컬 ad hoc 서명을 허용해 다시 실행했다. 서명 표시는 `Sign to Run Locally`였고, 개발자 팀은 빈 값으로 지정했다. 계정 로그인이나 계정 설정 변경은 하지 않았다. 읽기 전용 검사에서 두 상품 모두 로드됐고 `AppTransaction.environment == .xcode`를 확인했다. 기존 구매 테스트의 `.xcode` 안전 검사는 유지했다.

이 환경에서 구매·복원 테스트도 통과했다. 따라서 새 개발자 계정이나 sandbox 계정 인증을 요구할 근거가 없다. 처음의 noAccount는 로컬 QA 실행 환경의 장애였으며, Apple 심사 거절의 근본 원인으로 확정하지 않는다. 서명을 생략한 실행에서 StoreKit 환경이 달라진 내부 이유까지 확인한 것은 아니다.

## 검증 결과

- Xcode 27.0, 기존 iPhone 17 Pro Max / iOS 27.0 시뮬레이터.
- Mac 공유 코드 테스트 29개 통과: 기존 연결 테스트 26개와 새 상품 로딩 오류 테스트 3개.
- iOS 로컬 StoreKit 테스트 11개 통과, 0 실패. 상품 목록, 읽기 전용 환경 확인, 두 상품의 모의 구매·복원, 취소·환불·승인 대기, 조회·구매·복원 오류 복구, 빈 목록 및 부분 목록 복구를 포함한다.
- 로컬 모의 거래만 검사했다. Apple 서버의 sandbox 거래, TestFlight 구매·복원, 실기기 구매는 미검증이다.
- 수정된 plist/strings 파싱과 diff 공백 검사를 통과했다. 기존 미커밋 파일을 제외한 추적 소스의 별도 작업 사본에서 빌드했고, 해당 소스와 기존 저장소에 반영한 파일이 일치하는지 확인했다.

모의 구매 검사 예시(기존 시뮬레이터 UUID 사용):

```sh
xcodebuild test -project iPadMirrorPad.xcodeproj -scheme iPadMirrorQA \
  -destination 'platform=iOS Simulator,id=<existing-simulator-uuid>' \
  -derivedDataPath /tmp/screenmirror-ios-qa \
  -onlyUsePackageVersionsFromResolvedFile \
  -parallel-testing-enabled NO \
  -only-testing:iPadMirrorPadTests/StoreKitIntegrationTests \
  CODE_SIGNING_ALLOWED=YES CODE_SIGN_STYLE=Manual \
  'CODE_SIGN_IDENTITY=-' 'DEVELOPMENT_TEAM='
```

이 옵션은 해당 시뮬레이터 명령의 로컬 서명에만 적용된다. 프로젝트의 배포 서명·팀 설정을 바꾸지 않는다. StoreKit 환경 확인이 실패하면 계정 로그인이나 실제 구매로 진행하지 않는다.

## 남은 확인

Chrome 연결이 복구되면 한국어 이름·부제를 저장하고 실제 저장 결과를 확인해야 한다. 유료 앱 계약은 상태만 조회해야 하며 동의·금융정보·상품 가격을 변경하지 않는다. Apple sandbox의 상품 조회 및 구매·복원 검증이 필요하고, 심사에서 상품이 비어 나온 근본 원인은 아직 미확정이다. 영어 이름·부제에도 심사에서 지적된 명칭이 있으면 사용자가 정한 영어 이름이 추가로 필요하다.

새 빌드 업로드, 심사 답장, 재제출 또는 출시를 실행하지 않았다.
