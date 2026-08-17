import SwiftUI
import UIKit
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

struct BannerAdView: View {
    var body: some View {
        #if canImport(GoogleMobileAds)
        AdMobBannerRepresentable()
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Color.monitorSurfaceContainer)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.monitorOutline, lineWidth: 1)
            )
        #else
        Text("배너 광고는 Google Mobile Ads 연결 후 표시됩니다.")
            .font(.footnote)
            .foregroundStyle(Color.monitorOnSurfaceVariant)
            .frame(maxWidth: .infinity)
            .padding(16)
        #endif
    }
}

#if canImport(GoogleMobileAds)
private struct AdMobBannerRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: AdSizeLargeBanner)
        banner.adUnitID = MonetizationConfig.bannerAdUnitID
        banner.rootViewController = Self.topViewController()
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        uiView.rootViewController = Self.topViewController()
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windowScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? windowScene?.windows.first?.rootViewController
    }
}
#endif
