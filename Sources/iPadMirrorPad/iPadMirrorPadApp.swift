import AppTrackingTransparency
import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct iPadMirrorPadApp: App {
    init() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear(perform: requestTrackingIfNeeded)
        }
    }

    private func requestTrackingIfNeeded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            ATTrackingManager.requestTrackingAuthorization { _ in }
        }
    }
}
