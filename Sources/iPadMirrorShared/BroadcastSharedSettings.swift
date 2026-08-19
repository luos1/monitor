import Foundation

enum BroadcastSharedSettings {
    private static let extensionSuffix = ".BroadcastExtension"
    private static let stopRequestTokenKey = "stopRequestToken"
    private static let deviceNameKey = "deviceName"
    private static let pairingCodeKey = "pairingCode"
    private static let verifiedLifetimeKey = "verifiedLifetime"
    private static let entitlementVerifiedAtKey = "entitlementVerifiedAt"
    private static let pairingAlphabet = Array("23456789ABCDEFGHJKLMNPQRSTUVWXYZ")

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier())
    }

    static func appGroupIdentifier(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String {
        "group.\(baseBundleIdentifier(bundleIdentifier: bundleIdentifier))"
    }

    static func baseBundleIdentifier(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String {
        var identifier = bundleIdentifier ?? "com.raccoonmerchant.ipadmirror"
        if identifier.hasSuffix(extensionSuffix) {
            identifier.removeLast(extensionSuffix.count)
        }
        return identifier
    }

    static func writeDeviceName(_ name: String) {
        defaults?.set(name, forKey: deviceNameKey)
    }

    static func deviceName(fallback: String = "iPad") -> String {
        defaults?.string(forKey: deviceNameKey).flatMap { $0.isEmpty ? nil : $0 } ?? fallback
    }

    static func pairingCode() -> String {
        if let existing = defaults?.string(forKey: pairingCodeKey),
           normalizedPairingCode(existing).count == 8 {
            return normalizedPairingCode(existing)
        }

        let code = String((0..<8).compactMap { _ in pairingAlphabet.randomElement() })
        defaults?.set(code, forKey: pairingCodeKey)
        return code
    }

    static func formattedPairingCode() -> String {
        let code = pairingCode()
        let middle = code.index(code.startIndex, offsetBy: 4)
        return "\(code[..<middle])-\(code[middle...])"
    }

    static func normalizedPairingCode(_ code: String) -> String {
        code.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    static func cacheVerifiedLifetimeEntitlement(_ isUnlocked: Bool) {
        defaults?.set(isUnlocked, forKey: verifiedLifetimeKey)
        defaults?.set(Date().timeIntervalSince1970, forKey: entitlementVerifiedAtKey)
    }

    static func hasRecentVerifiedLifetimeEntitlement(
        now: Date = Date(),
        maximumAge: TimeInterval = 24 * 60 * 60
    ) -> Bool {
        guard defaults?.bool(forKey: verifiedLifetimeKey) == true else { return false }
        let verifiedAt = defaults?.double(forKey: entitlementVerifiedAtKey) ?? 0
        return verifiedAt > 0 && now.timeIntervalSince1970 - verifiedAt <= maximumAge
    }

    static func requestStop() {
        defaults?.set(UUID().uuidString, forKey: stopRequestTokenKey)
    }

    static func currentStopRequestToken() -> String? {
        defaults?.string(forKey: stopRequestTokenKey)
    }
}
