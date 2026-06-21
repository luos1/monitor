import Foundation

enum BroadcastSharedSettings {
    private static let extensionSuffix = ".BroadcastExtension"
    private static let stopRequestTokenKey = "stopRequestToken"
    private static let deviceNameKey = "deviceName"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupIdentifier())
    }

    static func appGroupIdentifier(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String {
        "group.\(baseBundleIdentifier(bundleIdentifier: bundleIdentifier))"
    }

    static func baseBundleIdentifier(bundleIdentifier: String? = Bundle.main.bundleIdentifier) -> String {
        var identifier = bundleIdentifier ?? "dev.local.iPadMirrorPad"
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

    static func requestStop() {
        defaults?.set(UUID().uuidString, forKey: stopRequestTokenKey)
    }

    static func currentStopRequestToken() -> String? {
        defaults?.string(forKey: stopRequestTokenKey)
    }
}
