import SwiftUI

public enum MonitorRole {
    case pad
    case mac

    public var companionTitle: String {
        switch self {
        case .pad:
            return "Mac 앱이 켜져 있어야 화면이 보입니다"
        case .mac:
            return "iPad 앱이 방송을 시작해야 화면을 받습니다"
        }
    }

    public var companionDetail: String {
        switch self {
        case .pad:
            return "이 앱은 화면을 보내는 역할입니다. Mac에서 아이패드미러를 함께 실행하세요."
        case .mac:
            return "이 앱은 화면을 받는 역할입니다. iPad에서 아이패드미러 방송을 시작하세요."
        }
    }

    public var onboardingSubtitle: String {
        switch self {
        case .pad:
            return "iPad 화면을 Mac으로 보내는 가장 단순한 방법입니다. 두 앱을 한 세트로 사용하세요."
        case .mac:
            return "iPad가 보낸 화면을 이 Mac에서 받습니다. 두 앱을 한 세트로 사용하세요."
        }
    }

    public var steps: [(String, String, String)] {
        switch self {
        case .pad:
            return [
                ("1", "Mac 앱 켜기", "아이패드미러 Mac을 먼저 실행해 받을 준비를 합니다."),
                ("2", "iPad에서 방송 시작", "전체 화면 공유를 누르고 ‘아이패드미러 방송’을 선택합니다."),
                ("3", "Mac에서 iPad 선택", "Mac 왼쪽 목록의 iPad 이름을 누르면 화면이 연결됩니다.")
            ]
        case .mac:
            return [
                ("1", "iPad 앱 준비", "iPad에서 아이패드미러를 열고 방송을 시작합니다."),
                ("2", "목록에서 선택", "왼쪽에 나타난 iPad 이름을 눌러 연결합니다."),
                ("3", "크게 보기", "화면이 잡히면 전체 크기로 전환해 작업합니다.")
            ]
        }
    }
}

public struct MonitorBrandMark: View {
    public var size: CGFloat = 56

    public init(size: CGFloat = 56) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(Color.monitorPrimary)
            Image(systemName: "rectangle.split.2x1")
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.monitorPrimary.opacity(0.28), radius: 12, y: 6)
        .accessibilityHidden(true)
    }
}

public struct MonitorUsageChip: View {
    public let remainingSeconds: Int
    public let lifetimeUnlocked: Bool
    public let remainingLabel: String

    public init(remainingSeconds: Int, lifetimeUnlocked: Bool, remainingLabel: String) {
        self.remainingSeconds = remainingSeconds
        self.lifetimeUnlocked = lifetimeUnlocked
        self.remainingLabel = remainingLabel
    }

    public var body: some View {
        let warning = !lifetimeUnlocked && remainingSeconds <= 10 * 60

        Label(lifetimeUnlocked ? "무제한" : remainingLabel, systemImage: lifetimeUnlocked ? "infinity" : "clock")
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(warning ? Color.monitorWarning : Color.monitorPrimary)
            .background(
                (warning ? Color.monitorWarning : Color.monitorPrimary).opacity(0.12),
                in: Capsule()
            )
            .accessibilityLabel(lifetimeUnlocked ? "사용 시간 무제한" : "남은 시간 \(remainingLabel)")
    }
}

public struct MonitorStatusOrb: View {
    public let isLive: Bool

    public init(isLive: Bool) {
        self.isLive = isLive
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill((isLive ? Color.monitorLive : Color.monitorPrimary).opacity(0.12))
                .frame(width: 112, height: 112)
            Circle()
                .fill(isLive ? Color.monitorLive : Color.monitorPrimary)
                .frame(width: 88, height: 88)
            Image(systemName: isLive ? "dot.radiowaves.left.and.right" : "ipad.and.iphone")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }
}

public struct MonitorCompanionBanner: View {
    public let role: MonitorRole

    public init(role: MonitorRole) {
        self.role = role
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "link")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.monitorWarning)
                .frame(width: 36, height: 36)
                .background(Color.monitorWarning.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(role.companionTitle)
                    .font(.headline)
                    .foregroundStyle(Color.monitorOnSurface)
                Text(role.companionDetail)
                    .font(.subheadline)
                    .foregroundStyle(Color.monitorOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)

                if StoreLinks.hasCompanionInstall {
                    Button("동반 앱 설치하기") {
                        StoreLinks.open(StoreLinks.companionInstallURL)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 4)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.monitorWarning.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

public struct MonitorGuideStep: View {
    public let number: String
    public let title: String
    public let detail: String

    public init(number: String, title: String, detail: String) {
        self.number = number
        self.title = title
        self.detail = detail
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline)
                .foregroundStyle(Color.monitorPrimary)
                .frame(width: 32, height: 32)
                .background(Color.monitorPrimaryContainer, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.monitorOnSurface)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.monitorOnSurfaceVariant)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.monitorSurfaceContainer, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.monitorOutline, lineWidth: 1)
        )
    }
}

public struct MonitorOnboardingView: View {
    public let role: MonitorRole
    public let onContinue: () -> Void

    public init(role: MonitorRole, onContinue: @escaping () -> Void) {
        self.role = role
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    MonitorBrandMark(size: 64)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(MonitorTheme.brandName)
                            .font(.largeTitle.weight(.semibold))
                        Text(role == .pad ? "보내는 앱" : "받는 앱")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.monitorPrimary)
                    }
                }

                Text(role.onboardingSubtitle)
                    .font(.title3)
                    .foregroundStyle(Color.monitorOnSurfaceVariant)

                MonitorCompanionBanner(role: role)

                ForEach(role.steps, id: \.0) { step in
                    MonitorGuideStep(number: step.0, title: step.1, detail: step.2)
                }

                MonitorCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("무료와 유료")
                            .font(.headline)
                        Text("처음 \(MonitorTheme.freeMinutes)분은 무료입니다. iPad에서는 AdMob 광고로 \(MonitorTheme.freeMinutes)분을 연장할 수 있고, 양쪽 앱에서 영구 사용 \(MonitorTheme.lifetimePrice) 또는 응원 \(MonitorTheme.donationPrice)을 구매할 수 있습니다.")
                            .font(.subheadline)
                            .foregroundStyle(Color.monitorOnSurfaceVariant)
                    }
                }

                Button(action: onContinue) {
                    Text("시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: MonitorTheme.primaryButtonHeight)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.monitorPrimary)
            }
            .padding(MonitorTheme.pagePadding)
        }
        .background(MonitorBackground())
    }
}

public struct MonitorPaywallView: View {
    @ObservedObject public var store: StorePurchaseManager
    public let remainingLabel: String
    public let title: String
    public let adsSupported: Bool
    public let adReady: Bool
    public let adPresenting: Bool
    public let adStatus: String
    public let onWatchAd: () -> Void
    public let onShowGuide: () -> Void

    public init(
        store: StorePurchaseManager,
        remainingLabel: String,
        title: String = "무료 \(MonitorTheme.freeMinutes)분이 끝났어요",
        adsSupported: Bool,
        adReady: Bool,
        adPresenting: Bool,
        adStatus: String,
        onWatchAd: @escaping () -> Void,
        onShowGuide: @escaping () -> Void
    ) {
        self.store = store
        self.remainingLabel = remainingLabel
        self.title = title
        self.adsSupported = adsSupported
        self.adReady = adReady
        self.adPresenting = adPresenting
        self.adStatus = adStatus
        self.onWatchAd = onWatchAd
        self.onShowGuide = onShowGuide
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.monitorWarning.opacity(0.14))
                        .frame(width: 112, height: 112)
                    Image(systemName: store.hasLifetimeEntitlement ? "checkmark.seal.fill" : "lock.fill")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(store.hasLifetimeEntitlement ? Color.monitorSuccess : Color.monitorWarning)
                }

                VStack(spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                    Text("AdMob 리워드 광고를 보면 \(MonitorTheme.freeMinutes)분을 더 쓸 수 있습니다. 영구 사용은 \(store.lifetimePriceLabel), 개발자 응원은 \(store.donationPriceLabel)입니다. 응원 구매 시 영구 사용도 함께 해제됩니다.")
                        .font(.title3)
                        .foregroundStyle(Color.monitorOnSurfaceVariant)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 12) {
                    Button(action: onWatchAd) {
                        Label(
                            adPresenting ? "광고 재생 중…" : "광고 보고 \(MonitorTheme.freeMinutes)분 연장",
                            systemImage: "play.rectangle.fill"
                        )
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: 420)
                        .frame(height: MonitorTheme.primaryButtonHeight)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.monitorPrimary)
                    .disabled(!adsSupported || adPresenting || store.isPurchasing)

                    Button {
                        Task { _ = await store.purchaseLifetime() }
                    } label: {
                        Label(
                            store.hasLifetimeEntitlement ? "영구 사용 해제됨" : "영구 사용 \(store.lifetimePriceLabel)",
                            systemImage: "cart.fill"
                        )
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: 420)
                        .frame(height: MonitorTheme.secondaryButtonHeight)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.canPurchaseLifetime)

                    Button {
                        Task { _ = await store.purchaseDonation() }
                    } label: {
                        Label("개발자 응원 \(store.donationPriceLabel)", systemImage: "heart.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: 420)
                            .frame(height: MonitorTheme.secondaryButtonHeight)
                    }
                    .buttonStyle(.bordered)
                    .disabled(!store.canPurchaseDonation)

                    Button {
                        Task { await store.restore() }
                    } label: {
                        Text(store.isRestoring ? "복원 중…" : "구매 복원")
                    }
                    .disabled(store.isRestoring || store.isPurchasing)
                }

                VStack(spacing: 6) {
                    Text(adsSupported ? adStatus : "광고 연장은 iPad 앱에서 사용할 수 있습니다. Mac에서는 인앱 결제로 잠금을 해제하세요.")
                    if let statusMessage = store.statusMessage {
                        Text(statusMessage)
                    }
                    if MonetizationConfig.usesGoogleSampleAds && adsSupported {
                        Text("지금은 Google 테스트 광고 ID를 사용합니다. AdMob 앱을 등록한 뒤 MonetizationConfig의 ID를 바꾸세요.")
                    }
                }
                .font(.footnote)
                .foregroundStyle(Color.monitorOnSurfaceVariant)
                .multilineTextAlignment(.center)

                Button("사용법 다시 보기", action: onShowGuide)
                    .padding(.top, 4)

                Text("남은 시간: \(remainingLabel)")
                    .font(.headline)
                    .foregroundStyle(Color.monitorOnSurfaceVariant)
            }
            .padding(MonitorTheme.pagePadding)
            .frame(maxWidth: .infinity)
        }
        .background(MonitorBackground())
    }
}
