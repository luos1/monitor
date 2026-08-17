import SwiftUI

public enum MonitorTheme {
    public static let brandName = "아이패드미러"
    public static let freeMinutes = 60
    public static let lifetimePrice = "$4.99"
    public static let donationPrice = "$99.99"

    public static let cardRadius: CGFloat = 24
    public static let buttonRadius: CGFloat = 20
    public static let chipRadius: CGFloat = 999
    public static let bezelRadius: CGFloat = 16
    public static let pagePadding: CGFloat = 24
    public static let cardPadding: CGFloat = 20
    public static let primaryButtonHeight: CGFloat = 56
    public static let secondaryButtonHeight: CGFloat = 48
}

public extension Color {
    static let monitorPrimary = Color(red: 0.231, green: 0.357, blue: 0.859)
    static let monitorPrimaryContainer = Color(red: 0.859, green: 0.894, blue: 1.0)
    static let monitorLive = Color(red: 0.878, green: 0.192, blue: 0.192)
    static let monitorSuccess = Color(red: 0.184, green: 0.620, blue: 0.267)
    static let monitorWarning = Color(red: 0.941, green: 0.549, blue: 0.0)
    static let monitorSurface = Color(red: 0.957, green: 0.965, blue: 0.984)
    static let monitorSurfaceContainer = Color.white
    static let monitorOnSurface = Color(red: 0.082, green: 0.098, blue: 0.137)
    static let monitorOnSurfaceVariant = Color(red: 0.361, green: 0.392, blue: 0.455)
    static let monitorOutline = Color(red: 0.835, green: 0.859, blue: 0.910)
    static let monitorCanvas = Color(red: 0.043, green: 0.051, blue: 0.071)
}

public struct MonitorBackground: View {
    public init() {}

    public var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.933, green: 0.949, blue: 1.0),
                Color.monitorSurface,
                Color(red: 0.973, green: 0.957, blue: 0.945)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

public struct MonitorCard<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .padding(MonitorTheme.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.monitorSurfaceContainer, in: RoundedRectangle(cornerRadius: MonitorTheme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MonitorTheme.cardRadius, style: .continuous)
                    .stroke(Color.monitorOutline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
    }
}
