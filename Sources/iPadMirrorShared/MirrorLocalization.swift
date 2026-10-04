import Foundation

public protocol MirrorLocalizedError: LocalizedError {}

public enum MirrorL10n {
    private static var resources: Bundle {
        #if SWIFT_PACKAGE
        if let url = Bundle.main.url(forResource: "iPadMirrorMac_iPadMirrorShared", withExtension: "bundle"),
           let bundle = Bundle(url: url) { return bundle }
        return .module
        #else
        return .main
        #endif
    }

    public static var preferredLanguage: String {
        language(for: Locale.preferredLanguages.first ?? "en")
    }

    public static func language(for languageCode: String) -> String {
        languageCode.lowercased().replacingOccurrences(of: "_", with: "-").split(separator: "-").first == "ko" ? "ko" : "en"
    }

    public static func text(_ key: String, language: String? = nil) -> String {
        let language = Self.language(for: language ?? preferredLanguage)
        guard let path = resources.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    public static func format(_ key: String, _ arguments: String..., language: String? = nil) -> String {
        var result = text(key, language: language)
        for (index, argument) in arguments.enumerated() {
            result = result.replacingOccurrences(of: "{\(index)}", with: argument)
        }
        return result
    }

    public static func errorMessage(_ error: Error) -> String {
        if let localized = error as? MirrorLocalizedError,
           let message = localized.errorDescription { return message }
        if (error as NSError).domain == NSURLErrorDomain {
            return text("인터넷 연결을 확인하고 다시 시도해 주세요.")
        }
        return text("작업을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.")
    }
}
