import AppTrackingTransparency
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct iPadMirrorPadApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: requestTrackingIfNeeded)
        }
    }

    private func requestTrackingIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
                ATTrackingManager.requestTrackingAuthorization { _ in
                    Self.startAdsAfterPrivacyChoice()
                }
            } else {
                Self.startAdsAfterPrivacyChoice()
            }
        }
    }

    private static func startAdsAfterPrivacyChoice() {
        DispatchQueue.main.async {
            #if canImport(GoogleMobileAds)
            MobileAds.shared.start { _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .monitorAdsMayLoad, object: nil)
                }
            }
            #else
            NotificationCenter.default.post(name: .monitorAdsMayLoad, object: nil)
            #endif
        }
    }
}

extension Notification.Name {
    static let monitorAdsMayLoad = Notification.Name("dev.local.iPadMirrorPad.adsMayLoad")
}
