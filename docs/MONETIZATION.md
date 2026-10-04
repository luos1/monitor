# 광고와 인앱 결제

| 기능 | iPad | Mac |
| --- | --- | --- |
| 리워드 광고 | SDK 보상 콜백 후 iPad 사용 시간 60분 연장 | iPad 보상과 동기화되지 않음 |
| 배너 | 개인정보 설정 확인 후 영구 사용 전 표시 | 없음 |
| 영구 사용/개발자 응원 | 검증된 현재 StoreKit entitlement | 별도 StoreKit entitlement |
| 구매 복원 | 두 Non-Consumable 상품 | 같은 ID 사용, 실제 배포/구매 검증 필요 |

기존 상품은 `ipadmirror.lifetime`, `ipadmirror.donation`입니다. 응원 상품도 영구 사용을 제공하도록 설계되어 있습니다. 가격은 StoreKit 현지화 표시 가격으로 보여 주며 로컬 구성의 $4.99/$99.99를 운영 가격 확정 근거로 삼지 않습니다. 취소·환불/만료/대체된 거래는 권한을 부여하지 않습니다.

## 광고 구성

| 구성 | 리워드 | 배너 |
| --- | --- | --- |
| Debug: Google 공식 데모 | `ca-app-pub-3940256099942544/1712485313` | `ca-app-pub-3940256099942544/2934735716` |
| Release: 기존 운영 단위 | `ca-app-pub-2932716467029728/6065803719` | `ca-app-pub-2932716467029728/3303909002` |

앱 ID는 `ca-app-pub-2932716467029728~6289164999`입니다. ID가 콘솔과 일치하는 것은 광고 게재 승인을 뜻하지 않습니다. 앱 검토 및 결제/개인정보 설정은 별도로 확인합니다.

UMP 정보 갱신과 필요한 동의 양식 이후 `canRequestAds`가 허용할 때 SDK와 광고를 시작합니다. ATT와 UMP 허용 상태는 별도로 처리합니다. UMP가 요구하는 경우 개인정보 설정 버튼이 표시되고 설정 변경 중 기존 리워드를 폐기합니다. 영구 사용이 인증되면 진행 중 광고 로드 결과도 반영하지 않습니다.

## 로컬 검증

1. Xcode Debug scheme의 기존 `Packaging/Products.storekit` 구성을 사용합니다. 이는 운영 구매 확인을 대신하지 않습니다.
2. Debug에서는 [Google 테스트 광고](https://developers.google.com/admob/ios/test-ads)를 사용합니다. 화면 확인만 할 때는 `-SkipAds`로 실행합니다.
3. 실제 광고 클릭, 운영 노출 반복, 실제 구매로 검증하지 않습니다.
4. 광고 성공/취소/실패, 보상 저장/재실행과 StoreKit 구매/복원/취소를 테스트 광고 및 승인된 샌드박스로 확인합니다.
5. 개인정보 신고는 [SDK 데이터 공개 안내](https://developers.google.com/admob/ios/privacy/data-disclosure), 포함된 manifest 및 실제 설정을 함께 확인해 작성합니다.

실기기 광고 보상/샌드박스 구매와 iPad↔Mac 권한 전달은 아직 검증되지 않았습니다. 출시 차단사항과 기존 등록 상태는 [LAUNCH.md](LAUNCH.md)에 기록합니다.
