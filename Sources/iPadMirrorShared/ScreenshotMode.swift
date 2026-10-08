#if DEBUG
import Foundation

public enum AppLocale: String {
    case ko
    case en
}

public enum ScreenshotMode {
    public static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-ScreenshotDemo")
    }

    public static var skipAds: Bool {
        isEnabled || ProcessInfo.processInfo.arguments.contains("-SkipAds")
    }

    public static var locale: AppLocale {
        guard let index = ProcessInfo.processInfo.arguments.firstIndex(of: "-ScreenshotLocale"),
              index + 1 < ProcessInfo.processInfo.arguments.count,
              let value = AppLocale(rawValue: ProcessInfo.processInfo.arguments[index + 1]) else {
            return .ko
        }
        return value
    }
}
#endif
