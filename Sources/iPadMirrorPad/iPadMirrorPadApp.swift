import AppTrackingTransparency
import SwiftUI
import UIKit
#if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
import GoogleMobileAds
import UserMessagingPlatform
#endif

@main
struct iPadMirrorPadApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }

}

/// UMP permission is required separately from ATT; state survives view recreation.
@MainActor
final class AdPrivacyController: ObservableObject {
    static let shared = AdPrivacyController()
    @Published private(set) var canLoadAds = false
    @Published private(set) var privacyOptionsRequired = false
    @Published private(set) var isPreparing = false
    @Published private(set) var status = "광고 개인정보 설정 확인 중"
    private var didPrepare = false
    private var didStartSDK = false
    private init() {}

    func prepareIfNeeded() {
        guard !didPrepare, !isPreparing, !ScreenshotMode.skipAds,
              UIApplication.shared.applicationState == .active else { return }
        didPrepare = true
        isPreparing = true
        Task {
            defer { isPreparing = false }
            #if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
            do {
                try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
                try await ConsentForm.loadAndPresentIfRequired(from: nil)
            } catch {
                status = "광고 개인정보 설정을 확인하지 못했습니다."
            }
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            await updateAdPermission()
            #else
            status = "광고를 현재 사용할 수 없습니다."
            #endif
        }
    }

    func presentPrivacyOptions() {
        guard privacyOptionsRequired, !isPreparing else { return }
        isPreparing = true
        canLoadAds = false
        Task {
            defer { isPreparing = false }
            #if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
            do {
                try await ConsentForm.presentPrivacyOptionsForm(from: nil)
            } catch {
                status = "개인정보 설정을 열지 못했습니다. 잠시 후 다시 시도해 주세요."
            }
            privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
            await updateAdPermission()
            #endif
        }
    }

    #if canImport(GoogleMobileAds) && canImport(UserMessagingPlatform)
    private func updateAdPermission() async {
        guard ConsentInformation.shared.canRequestAds, !ScreenshotMode.skipAds else {
            canLoadAds = false
            status = "광고를 현재 사용할 수 없습니다."
            return
        }
        if UIApplication.shared.applicationState == .active,
           ATTrackingManager.trackingAuthorizationStatus == .notDetermined {
            _ = await ATTrackingManager.requestTrackingAuthorization()
        }
        if !didStartSDK {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                MobileAds.shared.start { _ in continuation.resume() }
            }
            didStartSDK = true
        }
        canLoadAds = ConsentInformation.shared.canRequestAds && !ScreenshotMode.skipAds
        status = canLoadAds ? "광고 개인정보 설정 확인됨" : "광고를 현재 사용할 수 없습니다."
    }
    #endif
}
