import Combine
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@MainActor
final class AdRewardController: NSObject, ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isPresenting = false
    @Published var status = "광고 준비 중"

    let isSupported = true

    #if canImport(GoogleMobileAds)
    private var rewardedAd: RewardedAd?
    private var presentation: AdPresentation?
    #endif

    func start() {
        #if canImport(GoogleMobileAds)
        Task { [weak self] in
            await self?.load()
        }
        #else
        status = "Xcode에서 Google Mobile Ads 패키지를 받으면 광고가 활성화됩니다."
        #endif
    }

    func load() async {
        #if canImport(GoogleMobileAds)
        do {
            let ad = try await RewardedAd.load(with: MonetizationConfig.rewardedAdUnitID, request: Request())
            rewardedAd = ad
            isReady = true
            status = MonetizationConfig.usesGoogleSampleAds ? "테스트 광고 준비됨" : "광고 준비됨"
        } catch {
            rewardedAd = nil
            isReady = false
            status = "광고 로드 실패: \(error.localizedDescription)"
        }
        #endif
    }

    func showRewarded() async throws {
        #if canImport(GoogleMobileAds)
        guard let rewardedAd, let presenter = Self.topViewController() else {
            throw AdRewardError.notReady
        }

        isPresenting = true
        isReady = false
        self.rewardedAd = nil

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

        isPresenting = false
        presentation = nil
        await load()

        if earned {
            status = "광고를 보고 \(MonitorTheme.freeMinutes)분이 연장되었습니다."
        } else {
            throw AdRewardError.noReward
        }
        #else
        throw AdRewardError.failed("Google Mobile Ads SDK가 연결되어 있지 않습니다.")
        #endif
    }

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
        complete(.failure(AdRewardError.failed(error.localizedDescription)))
    }

    private func complete(_ result: Result<Bool, Error>) {
        guard !didFinish else { return }
        didFinish = true
        finish(result)
    }
}
#endif
