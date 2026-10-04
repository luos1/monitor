import Foundation

public enum MonetizationConfig {
    /// AdMob 앱 ID (아이패드미러)
    public static let admobAppID = "ca-app-pub-2932716467029728~6289164999"
    #if DEBUG
    public static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    public static let bannerAdUnitID = "ca-app-pub-3940256099942544/2934735716"
    #else
    public static let rewardedAdUnitID = "ca-app-pub-2932716467029728/6065803719"
    public static let bannerAdUnitID = "ca-app-pub-2932716467029728/3303909002"
    #endif

    public static let lifetimeProductID = "ipadmirror.lifetime"
    public static let donationProductID = "ipadmirror.donation"

    public static var productIDs: Set<String> {
        [lifetimeProductID, donationProductID]
    }

    public static var usesGoogleSampleAds: Bool {
        rewardedAdUnitID.contains("3940256099942544")
            || bannerAdUnitID.contains("3940256099942544")
    }
}

public enum RewardedAdCachePolicy {
    // Google rewarded ads expire after one hour; refresh before that boundary.
    public static let maximumAge: TimeInterval = 55 * 60

    public static func isFresh(loadedAt: Date?, now: Date = Date()) -> Bool {
        guard let loadedAt else { return false }
        let age = now.timeIntervalSince(loadedAt)
        return age >= 0 && age < maximumAge
    }
}

public enum MonetizationOutcome: String, Equatable {
    case rewardedAdFinished
    case lifetimeUnlocked
    case donationCompleted
}

public enum StoreEntitlementPolicy {
    public static func grantsLifetime(
        productID: String,
        revocationDate: Date?,
        expirationDate: Date?,
        isUpgraded: Bool,
        now: Date = Date()
    ) -> Bool {
        MonetizationConfig.productIDs.contains(productID)
            && revocationDate == nil
            && !isUpgraded
            && (expirationDate.map { $0 > now } ?? true)
    }
}

public enum MonetizationApplier {
    @MainActor
    public static func apply(_ outcome: MonetizationOutcome, to usage: UsageAccessManager) {
        switch outcome {
        case .rewardedAdFinished:
            usage.grantAdExtension(minutes: MonitorTheme.freeMinutes)
        case .lifetimeUnlocked, .donationCompleted:
            usage.unlockLifetime()
        }
    }
}

public enum AdRewardError: MirrorLocalizedError, Equatable {
    case unsupported
    case notReady
    case failed(String)
    case noReward

    public var errorDescription: String? {
        switch self {
        case .unsupported:
            return MirrorL10n.text("광고 연장은 iPad 앱에서 사용할 수 있습니다.")
        case .notReady:
            return MirrorL10n.text("광고를 아직 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.")
        case .failed(let message):
            return message
        case .noReward:
            return MirrorL10n.text("광고를 끝까지 보지 않아 시간이 연장되지 않았습니다.")
        }
    }
}
