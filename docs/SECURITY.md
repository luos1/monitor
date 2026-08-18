# 아이패드미러 보안 설계

## 화면 전송

- 방송 확장은 최대 4개 연결만 동시에 처리합니다.
- 각 연결은 10초 안에 iPad 앱에 표시된 8자리 연결 코드로 인증해야 합니다.
- 연결 코드는 네트워크로 직접 보내지 않습니다. 무작위 challenge에 대한
  HMAC-SHA256 응답으로 소유 여부를 확인합니다.
- 인증 후 각 JPEG 프레임을 ChaCha20-Poly1305로 암호화하고 무결성을 검증합니다.
- 느린 클라이언트의 대기 프레임은 연결당 최대 3개로 제한합니다.
- 프레임 수신 크기는 20MB로 제한하며 인증 또는 복호화 실패 시 연결을 종료합니다.
- 복호화한 JPEG는 디코딩 전에 형식·가로·세로·총 픽셀 수를 검사합니다.
- AWDL 근거리 P2P 탐색은 비활성화하고 Bonjour에는 실제 기기명을 게시하지 않습니다.

연결 코드는 App Group의 로컬 `UserDefaults`에만 저장됩니다. 코드가 노출된 경우
앱을 삭제 후 재설치하면 새 코드가 생성됩니다.

## 구매 권한

영구 사용 여부는 로컬 플래그를 신뢰하지 않고 StoreKit 2의 검증된
`Transaction.currentEntitlements` 결과로 결정합니다. 영구 사용과 개발자 응원
상품은 모두 Non-Consumable이어야 구매 복원과 환불 상태를 반영할 수 있습니다.
방송 확장은 App Group에 캐시된 최근 StoreKit 검증 결과와 실제 방송 사용시간을
확인하며, 무료 시간이 끝나면 ReplayKit 방송을 종료합니다.

## 개인정보와 광고

iPad 앱은 광고 추적 가능성을 Privacy Manifest와 App Store 개인정보 설문에
공개하고 ATT 권한을 요청합니다. Google Mobile Ads SDK는 검토된 12.14.0 버전으로
고정합니다. 출시 전 AdMob의 **개인정보 보호 및 메시지**에서 적용 지역의 동의
메시지를 게시하고 실제 기기의 App Privacy Report를 확인해야 합니다.

## 출시 전 운영 확인

- 배포용 Bundle ID와 App Group으로 교체
- Release 아카이브의 Privacy Report 검토
- AdMob 테스트 기기에서 광고 및 동의 흐름 검증
- 실제 서로 다른 Wi-Fi 클라이언트로 잘못된 코드, 패킷 변조, 느린 수신 테스트
- Mac 직접 배포 시 Developer ID 서명, Hardened Runtime, 공증 적용
