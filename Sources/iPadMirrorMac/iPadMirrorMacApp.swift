import SwiftUI

@main
struct iPadMirrorMacApp: App {
    var body: some Scene {
        WindowGroup {
            ReceiverView() // 미러링 UI로 바로 진입
        }
    }
}
