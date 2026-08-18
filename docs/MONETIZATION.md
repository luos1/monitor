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
2. iPad 앱은 아래 실제 AdMob ID로 광고가 나갑니다. 개발 중에는 AdMob 콘솔에서 테스트 기기를 등록하세요.

## 연결된 AdMob ID

| 항목 | ID |
| --- | --- |
| 앱 | `ca-app-pub-2932716467029728~6289164999` |
| 리워드 (아이패드미러 리워드) | `ca-app-pub-2932716467029728/6065803719` |
| 배너 (아이패드미러 배너) | `ca-app-pub-2932716467029728/3303909002` |

코드 위치: `Sources/iPadMirrorShared/MonetizationConfig.swift`, `Sources/iPadMirrorPad/Info.plist` (`GADApplicationIdentifier`)

## 기타 출시 설정

코드와 로컬 StoreKit 구성은 App Store Connect 상품 ID와 동일하게 유지합니다.

## App Store Connect 상품

- `ipadmirror.lifetime` : Non-Consumable, $4.99
- `ipadmirror.donation` : Non-Consumable, $99.99

응원 상품도 영구 사용 권한을 제공하므로 반드시 **Non-Consumable**로 등록해야
복원·환불·기기 변경 시 StoreKit entitlement를 정확히 반영할 수 있습니다.
Consumable로 등록하면 영구 권한의 복원과 검증이 불가능합니다.

번들 ID를 바꾸면 상품 ID prefix도 같이 바꾸는 것을 권장합니다.

## AdMob

1. iOS 앱과 리워드/배너 단위는 등록 완료
2. 개발 기기는 AdMob 콘솔 → 설정 → 테스트 기기에 등록
3. 스토어 개인정보 설문에 광고 항목 표시
