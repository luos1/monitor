import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

public enum StoreLinks {
    public static let companionInstallURL: URL? = nil
    public static let privacyPolicyURL: URL? = nil
    public static let supportEmail = "intheluos@gmail.com"

    public static var hasCompanionInstall: Bool { companionInstallURL != nil }

    public static func open(_ url: URL?) {
        guard let url else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }
}
