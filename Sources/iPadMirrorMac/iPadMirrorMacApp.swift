import iPadMirrorShared
import SwiftUI

@main
struct iPadMirrorMacApp: App {
    var body: some Scene {
        WindowGroup {
            ReceiverView()
        }
        .defaultSize(width: 1100, height: 740)
        .commands {
            CommandGroup(replacing: .help) {
                Button(MirrorL10n.text("아이패드미러 사용법")) {
                    NotificationCenter.default.post(name: .monitorShowUsageGuide, object: nil)
                }
            }
        }
    }
}

extension Notification.Name {
    static let monitorShowUsageGuide = Notification.Name("monitor.showUsageGuide")
}
