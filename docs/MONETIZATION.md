# 광고와 인앱 결제

## 동작

| 기능 | iPad | Mac |
| --- | --- | --- |
| AdMob 리워드 광고로 60분 연장 | 지원 | 미지원 (안내만) |
| AdMob 배너 (홈 화면) | 영구 사용 전에는 표시 | 없음 |
| 영구 사용 `$4.99` | StoreKit 2 | StoreKit 2 |
| 개발자 응원 `$99.99` | StoreKit 2, 구매 시 영구 사용도 해제 | 동일 |
| 구매 복원 | 영구 사용 상품 | 영구 사용 상품 |

광고 보상은 사용자가 리워드 광고를 끝까지 본 뒤에만 지급합니다. 전면광고를 보상처럼 강제하지 않습니다.

## 로컬 테스트

1. Xcode scheme의 StoreKit Configuration에 `Packaging/Products.storekit` 를 연결합니다.
2. iPad 앱은 Google 샘플 AdMob ID로 테스트 광고가 나옵니다.
3. 실제 수익을 내려면 아래 ID를 교체합니다.

## 출시 시 교체

`Sources/iPadMirrorShared/MonetizationConfig.swift`

- `admobAppID`
- `rewardedAdUnitID`
- `bannerAdUnitID`
- `lifetimeProductID`
- `donationProductID`

`Sources/iPadMirrorPad/Info.plist` 의 `GADApplicationIdentifier` 도 같은 앱 ID로 맞춥니다.

## App Store Connect 상품

- `dev.local.iPadMirror.lifetime` : Non-Consumable, $4.99
- `dev.local.iPadMirror.donation` : Consumable, $99.99

번들 ID를 바꾸면 상품 ID prefix도 같이 바꾸는 것을 권장합니다.

## AdMob

1. https://apps.admob.com 에서 iOS 앱 등록
2. 리워드 광고 단위, 배너 광고 단위 생성
3. 테스트 기기 등록 후 샘플 ID를 실제 ID로 교체
4. 스토어 개인정보 설문에 광고 항목 표시
