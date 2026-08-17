# iPad 앱

ReplayKit Broadcast Upload Extension으로 홈 화면과 다른 앱을 포함한 iPad 현재 화면을 Mac 앱에 전송합니다.

## 파일

- `iPadMirrorPadApp.swift` : 앱 진입점
- `ContentView.swift` : 온보딩, 방송 제어, 잠금 화면
- `BroadcastPickerButton.swift` : 시스템 방송 시작 버튼
- `BroadcastControllerModel.swift` : 방송 종료 제어
- `../iPadMirrorShared` : 테마, 사용 시간, 스토어 링크

## 사용

`iPadMirrorPad.xcodeproj`를 열고 iPad에 설치합니다. Mac 앱을 먼저 켠 뒤 iPad에서 전체 화면 공유를 시작하고, 방송 선택창에서 `아이패드미러 방송`을 고르면 Mac 목록에 iPad 이름이 나타납니다.
