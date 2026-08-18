# 아이패드미러 출시 준비

기준일: 2026-08-17. 기능 코어는 동작하고, 이번 작업으로 UI와 출시 문서를 맞췄습니다.

## 현재 완료

- [x] iPad ReplayKit 방송 + Bonjour/USB 전송
- [x] Mac 수신, 장치 목록, 전체 창 보기
- [x] 첫 실행 사용법
- [x] 60분 제한, 광고 연장, 평생 해제 로직과 테스트
- [x] 앱 아이콘
- [x] Google Stitch 토큰(`DESIGN.md`)과 iPad/Mac UI 적용
- [x] 스토어 문구, 개인정보 처리방침 초안, 출시 체크리스트
- [x] Mac 버전을 1.0.0으로 맞춤
- [x] Privacy Manifest, Export Compliance, App Group 서명 설정
- [x] AdMob 리워드/배너 (iPad, 테스트 ID)
- [x] StoreKit 2 영구 사용 $4.99 / 응원 $99.99

## 출시 직전 필수 (코드 밖)

- [ ] Apple Developer 계정에서 번들 ID를 `dev.local.*`에서 배포용으로 변경
- [ ] App Group, 서명, Provisioning Profile
- [ ] App Store Connect에 iPad 앱 생성
- [ ] Mac 앱은 Mac App Store 또는 직접 배포 중 선택
- [x] AdMob 실제 앱/리워드/배너 ID 연결
- [ ] App Store Connect에 `ipadmirror.lifetime`, `ipadmirror.donation`을 Non-Consumable 상품으로 등록
- [ ] `StoreLinks.swift`에 동반 앱/개인정보 처리방침 URL 입력
- [ ] 개인정보 처리방침을 공개 URL에 게시
- [ ] iPad와 Mac 실기기 페어 테스트 (Wi-Fi, USB, 방송 종료)
- [ ] 스토어 스크린샷 6장 이상 (온보딩, 홈, 방송 중, Mac 수신, 잠금)
- [ ] 연령 등급, 수출 규정, 개인정보 설문

## 권장 심사 메모

이 앱은 ReplayKit Broadcast Upload Extension으로 iPad 화면을 같은 사용자의 Mac에만 보냅니다. 화면 내용은 서버로 업로드되지 않고 로컬 네트워크 또는 USB로만 전달됩니다. Mac은 iPad에 표시된 8자리 연결 코드로 인증되며, 프레임은 ChaCha20-Poly1305로 암호화·무결성 검증됩니다.

## 심사에서 막히기 쉬운 지점

- 로컬 네트워크 사용 설명이 Info.plist와 실제 동작과 같아야 합니다.
- 광고/IAP 버튼은 실제 StoreKit·AdMob 흐름에 연결되어 있습니다. 로컬에서는 `Packaging/Products.storekit` 과 Google 테스트 광고 ID를 사용하세요.
- Broadcast Extension 표시 이름은 `아이패드미러 방송`입니다. 사용법 문구와 같아야 합니다.
- 번들 ID `dev.local.*`는 스토어 제출에 적합하지 않습니다.

## 제출 순서

1. URL과 번들 ID를 채운 뒤 TestFlight 내부 테스트
2. iPad 앱 심사 제출
3. Mac 앱 배포(스토어 또는 다운로드 페이지)
4. 양쪽 라이브 URL을 `StoreLinks`와 온보딩 배너에 연결
5. 1.0.1로 동반 앱 링크만 갱신해도 됩니다
