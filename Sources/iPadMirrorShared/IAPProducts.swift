import Foundation

/// App Store Connect에 등록하는 Non-Consumable 상품 ID.
/// 표시 이름·가격은 스토어 메타데이터와 `Configuration/Products.storekit`과 같아야 한다.
public enum IAPProductID: String, CaseIterable, Identifiable, Sendable {
    case lifetime = "ipadmirror.lifetime"
    case donation = "ipadmirror.donation"

    public var id: String { rawValue }

    public var grantsLifetimeUnlock: Bool { true }

    public static let allIDs: Set<String> = Set(allCases.map(\.rawValue))

    public var fallbackDisplayName: String {
        let korean = Locale.current.language.languageCode?.identifier == "ko"
        switch self {
        case .lifetime:
            return korean ? "평생 사용" : "Lifetime Unlock"
        case .donation:
            return korean ? "개발자 응원" : "Developer Support"
        }
    }

    public var fallbackPriceLabel: String {
        switch self {
        case .lifetime:
            return MonitorTheme.lifetimePrice
        case .donation:
            return MonitorTheme.donationPrice
        }
    }
}
