import Combine
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdRewardController: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isPresenting = false
    @Published private(set) var isLoading = false
    @Published var status = MirrorL10n.text("광고 준비 중")

    let isSupported = true

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    private var rewardedAdLoadedAt: Date?
    private var presentation: AdPresentation?
    private var loadID: UUID?
    #endif

    func start() {
        #if canImport(GoogleMobileAds)
        Task { [weak self] in
            await self?.load()
        }
        #else
        status = MirrorL10n.text("Xcode에서 Google Mobile Ads 패키지를 받으면 광고가 활성화됩니다.")
        #endif
    }

    func load() async {
        #if canImport(GoogleMobileAds)
        expireCachedAdIfNeeded()
        #if DEBUG
        guard !ScreenshotMode.skipAds else { return }
        #endif
        guard AdPrivacyController.shared.canLoadAds,
              !BroadcastSharedSettings.hasRecentVerifiedLifetimeEntitlement(),
              loadID == nil, !isPresenting, rewardedAd == nil else { return }
        let requestID = UUID()
        loadID = requestID
        isLoading = true
        status = MirrorL10n.text("광고 준비 중")
        defer {
            if loadID == requestID {
                loadID = nil
                isLoading = false
            }
        }
        do {
            let ad = try await RewardedAd.load(with: MonetizationConfig.rewardedAdUnitID, request: Request())
            guard loadID == requestID, AdPrivacyController.shared.canLoadAds,
                  !BroadcastSharedSettings.hasRecentVerifiedLifetimeEntitlement() else { return }
            rewardedAd = ad
            rewardedAdLoadedAt = Date()
            isReady = true
            status = MonetizationConfig.usesGoogleSampleAds ? MirrorL10n.text("테스트 광고 준비됨") : MirrorL10n.text("광고 준비됨")
        } catch {
            guard loadID == requestID else { return }
            rewardedAd = nil
            rewardedAdLoadedAt = nil
            isReady = false
            status = MirrorL10n.format("광고 로드 실패: {0}", String(describing: MirrorL10n.errorMessage(error)))
        }
        #endif
    }

    func showRewarded() async throws {
        #if canImport(GoogleMobileAds)
        expireCachedAdIfNeeded()
        #if DEBUG
        guard !ScreenshotMode.skipAds else { throw AdRewardError.notReady }
        #endif
        guard !isPresenting, AdPrivacyController.shared.canLoadAds else { throw AdRewardError.notReady }
        guard let rewardedAd, let presenter = Self.topViewController() else {
            throw AdRewardError.notReady
        }

        isPresenting = true
        isReady = false
        self.rewardedAd = nil
        rewardedAdLoadedAt = nil

        // Restore the button even when the SDK fails to present the ad.
        defer {
            withExtendedLifetime(rewardedAd) {}
            isPresenting = false
            presentation = nil
            start()
        }

        let earned = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            let presentation = AdPresentation { result in
                continuation.resume(with: result)
            }
            self.presentation = presentation
            rewardedAd.fullScreenContentDelegate = presentation
            rewardedAd.present(from: presenter) {
                presentation.earnedReward = true
            }
        }

        if earned {
            status = MirrorL10n.format("광고를 보고 {0}분이 연장되었습니다.", String(describing: MonitorTheme.freeMinutes))
        } else {
            throw AdRewardError.noReward
        }
        #else
        throw AdRewardError.failed(MirrorL10n.text("Google Mobile Ads SDK가 연결되어 있지 않습니다."))
        #endif
    }

    func invalidate() {
        #if canImport(GoogleMobileAds)
        loadID = nil
        rewardedAd = nil
        rewardedAdLoadedAt = nil
        isLoading = false
        #endif
        isReady = false
    }

    #if canImport(GoogleMobileAds)
    private func expireCachedAdIfNeeded() {
        guard rewardedAd != nil,
              !RewardedAdCachePolicy.isFresh(loadedAt: rewardedAdLoadedAt) else { return }
        rewardedAd = nil
        rewardedAdLoadedAt = nil
        isReady = false
        status = MirrorL10n.text("광고 준비 중")
    }
    #endif

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windowScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? windowScene?.windows.first?.rootViewController else {
            return nil
        }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}

#if canImport(GoogleMobileAds)
private final class AdPresentation: NSObject, FullScreenContentDelegate {
    var earnedReward = false
    private let finish: (Result<Bool, Error>) -> Void
    private var didFinish = false

    init(finish: @escaping (Result<Bool, Error>) -> Void) {
        self.finish = finish
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        complete(.success(earnedReward))
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        complete(.failure(AdRewardError.failed(MirrorL10n.errorMessage(error))))
    }

    private func complete(_ result: Result<Bool, Error>) {
        guard !didFinish else { return }
        didFinish = true
        finish(result)
    }
}
#endif
