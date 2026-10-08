import Foundation
import SwiftUI
import iPadMirrorShared

enum MacDistribution {
    static var isNetworkOnly: Bool {
        #if IPADMIRROR_MAC_APP_STORE
        true
        #else
        false
        #endif
    }
}

enum MacStoreCopy {
    static func text(_ korean: String, _ english: String, language: String? = nil) -> String {
        MirrorL10n.language(for: language ?? MirrorL10n.preferredLanguage) == "ko" ? korean : english
    }
    static var searching: String { text("로컬 네트워크에서 iPad 화면 방송 검색 중…", "Searching for iPad broadcasts on the local network…") }
    static var encryptedConnection: String { text("로컬 네트워크 · 암호화 연결", "Local network · encrypted connection") }
    static var emptyInstructions: String { text("두 기기를 같은 네트워크에 연결하고 iPad 앱에서 방송을 시작하세요.", "Connect both devices to the same network and start broadcasting in the iPad app.") }
    static var networkRequirement: String { text("Mac과 iPhone 또는 iPad를 서로 연결 가능한 같은 로컬 네트워크에 연결하고 두 앱을 켜세요. 요청되면 두 기기의 로컬 네트워크 접근을 허용하세요.", "Connect your Mac and iPhone or iPad to the same reachable local network and open both apps. Allow local network access on both devices when requested.") }
    static var pairingInstructions: String { text("송신 앱 홈 화면의 8자리 연결 코드를 입력한 뒤 왼쪽 목록에서 해당 기기를 선택하세요.", "Enter the eight-character code from the sender app home screen, then select that device in the list.") }
    static var storeTransport: String { text("이 Mac App Store 버전은 로컬 네트워크로 연결합니다. USB 케이블만 연결해서는 미러링할 수 없습니다.", "This Mac App Store version connects over your local network. A USB cable alone does not provide mirroring.") }
}

struct MacStoreNetworkGuide: View {
    let onContinue: () -> Void
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    MonitorBrandMark(size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(MonitorTheme.brandName).font(.largeTitle.weight(.semibold))
                        Text(MirrorL10n.text("받는 앱")).font(.subheadline.weight(.semibold)).foregroundStyle(Color.monitorPrimary)
                    }
                }
                Text(MacStoreCopy.text("iPad 화면을 같은 네트워크의 Mac에서 받습니다.", "Receive your iPad screen on a Mac on the same network."))
                    .font(.title3).foregroundStyle(Color.monitorOnSurfaceVariant)
                MonitorCompanionBanner(role: .mac)
                MonitorGuideStep(number: "1", title: MacStoreCopy.text("같은 네트워크에 연결", "Connect to the same network"), detail: MacStoreCopy.networkRequirement)
                MonitorGuideStep(number: "2", title: MirrorL10n.text("이 기기에서 방송 시작"), detail: MirrorL10n.text("전체 화면 방송 시작을 누르고 ‘아이패드미러 방송’을 선택한 뒤 방송 시작을 확인하세요."))
                MonitorGuideStep(number: "3", title: MirrorL10n.text("코드 입력 후 기기 선택"), detail: MacStoreCopy.pairingInstructions)
                MonitorCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(MirrorL10n.text("Mac은 무료 동반 앱입니다")).font(.headline)
                        Text(MirrorL10n.text("Mac 수신 앱은 시간 제한과 별도 구매 없이 무료로 사용할 수 있습니다. iPad 송신 앱의 사용 시간과 구매 조건은 iPad에서 확인하세요."))
                        Text(MacStoreCopy.storeTransport)
                    }
                    .font(.subheadline).foregroundStyle(Color.monitorOnSurfaceVariant)
                }
                Button(action: onContinue) {
                    Text(MirrorL10n.text("시작하기")).font(.headline).frame(maxWidth: .infinity).frame(height: MonitorTheme.primaryButtonHeight)
                }
                .buttonStyle(.borderedProminent).tint(Color.monitorPrimary)
            }
            .padding(MonitorTheme.pagePadding)
        }
        .background(MonitorBackground())
    }
}
