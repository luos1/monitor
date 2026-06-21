# iPadMirrorPad

iPad 앱은 ReplayKit Broadcast Upload Extension으로 홈 화면과 다른 앱을 포함한 iPad 현재 화면을 Mac 앱에 전송합니다.

## 파일 구성

- iPadMirrorPadApp.swift : SwiftUI 앱 진입점
- ContentView.swift      : 전체 화면 공유 시작/종료 UI
- BroadcastControllerModel.swift: ReplayKit 방송 시작/종료 제어
- Info.plist             : 로컬 네트워크/Bonjour 권한 및 번들 정보
- ../iPadMirrorBroadcastExtension: 전체 화면 방송 확장 소스

## 사용법

`iPadMirrorPad.xcodeproj`를 열고 iPad에 설치합니다. iPad 앱에서 `전체 화면 공유 시작`을 누르고 방송 선택창에서 `iPad Mirror Broadcast`를 시작하면 Mac 앱 목록에 실제 iPad 이름이 표시됩니다. iPad 앱의 `화면 공유 종료`를 누르면 방송이 종료됩니다.