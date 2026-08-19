import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("monitor.pad.didShowUsageGuide") private var didShowUsageGuide = false
    @State private var showingUsageGuide = false
    @State private var showingUpgrade = false
    @State private var adsMayLoad = false
    @StateObject private var usageAccess = UsageAccessManager(
        namespace: "monitor.pad",
        suiteName: BroadcastSharedSettings.appGroupIdentifier()
    )
    @StateObject private var broadcast = BroadcastControllerModel()
    @StateObject private var store = StorePurchaseManager()
    @StateObject private var ads = AdRewardController()

    private var broadcastExtensionIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "com.raccoonmerchant.ipadmirror").BroadcastExtension"
    }

    var body: some View {
        Group {
            if usageAccess.isLocked {
                paywall(title: "무료 \(MonitorTheme.freeMinutes)분이 끝났어요")
            } else if didShowUsageGuide {
                mainContent
            } else {
                MonitorOnboardingView(role: .pad) {
                    didShowUsageGuide = true
                }
            }
        }
        .sheet(isPresented: $showingUsageGuide) {
            MonitorOnboardingView(role: .pad) {
                didShowUsageGuide = true
                showingUsageGuide = false
            }
            .frame(minWidth: 640, minHeight: 720)
        }
        .sheet(isPresented: $showingUpgrade) {
            paywall(title: "유료 기능")
                .frame(minWidth: 640, minHeight: 720)
        }
        .onAppear {
            usageAccess.reloadStoredUsage()
            store.start()
            syncPurchaseState()
        }
        .onReceive(NotificationCenter.default.publisher(for: .monitorAdsMayLoad)) { _ in
            adsMayLoad = true
            ads.start()
        }
        .onChange(of: store.hasLifetimeEntitlement) { _, unlocked in
            usageAccess.setLifetimeEntitlement(unlocked)
            BroadcastSharedSettings.cacheVerifiedLifetimeEntitlement(unlocked)
        }
        .onChange(of: store.didRefreshEntitlements) { _, didRefresh in
            if didRefresh {
                syncPurchaseState()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            usageAccess.reloadStoredUsage()
            Task {
                await store.refreshEntitlements()
            }
        }
    }

    private func paywall(title: String) -> some View {
        MonitorPaywallView(
            store: store,
            remainingLabel: usageAccess.remainingTimeLabel,
            title: title,
            adsSupported: ads.isSupported,
            adReady: ads.isReady,
            adPresenting: ads.isPresenting,
            adStatus: ads.status,
            onWatchAd: watchAd,
            onShowGuide: { showingUsageGuide = true }
        )
    }

    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    HStack(spacing: 10) {
                        MonitorBrandMark(size: 40)
                        Text(MonitorTheme.brandName)
                            .font(.title2.weight(.semibold))
                    }
                    Spacer()
                    MonitorUsageChip(
                        remainingSeconds: usageAccess.remainingSeconds,
                        lifetimeUnlocked: usageAccess.lifetimeUnlocked,
                        remainingLabel: usageAccess.remainingTimeLabel
                    )
                }

                MonitorCard {
                    VStack(spacing: 16) {
                        MonitorStatusOrb(isLive: broadcast.isBroadcasting)

                        VStack(spacing: 8) {
                            Text(broadcast.isBroadcasting ? "화면을 보내는 중" : "보낼 준비가 되었습니다")
                                .font(.title.weight(.semibold))
                            Text("이 iPad는 화면을 보내는 역할입니다. Mac 앱이 함께 켜져 있어야 미러링이 보입니다.")
                                .font(.body)
                                .foregroundStyle(Color.monitorOnSurfaceVariant)
                                .multilineTextAlignment(.center)
                        }

                        Text(broadcast.status)
                            .font(.headline)
                            .foregroundStyle(broadcast.isBroadcasting ? Color.monitorLive : Color.monitorOnSurfaceVariant)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                }

                MonitorCard {
                    HStack(spacing: 14) {
                        Image(systemName: "lock.shield.fill")
                            .font(.title2)
                            .foregroundStyle(Color.monitorPrimary)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Mac 연결 코드")
                                .font(.headline)
                            Text(BroadcastSharedSettings.formattedPairingCode())
                                .font(.system(.title2, design: .monospaced, weight: .bold))
                                .textSelection(.enabled)
                            Text("Mac 앱에 이 코드를 입력해야 화면을 받을 수 있습니다.")
                                .font(.caption)
                                .foregroundStyle(Color.monitorOnSurfaceVariant)
                        }
                        Spacer()
                    }
                }

                MonitorCompanionBanner(role: .pad)

                VStack(spacing: 12) {
                    BroadcastPickerButton(preferredExtension: broadcastExtensionIdentifier)
                        .frame(maxWidth: 420, minHeight: MonitorTheme.primaryButtonHeight, maxHeight: 64)
                        .accessibilityLabel("전체 화면 공유 시작")

                    Button {
                        broadcast.stopBroadcast()
                    } label: {
                        Label("화면 공유 종료", systemImage: "stop.circle.fill")
                            .font(.title3.weight(.semibold))
                            .frame(maxWidth: 420)
                            .frame(height: MonitorTheme.secondaryButtonHeight)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.monitorOnSurfaceVariant)

                    if !usageAccess.lifetimeUnlocked {
                        Button {
                            showingUpgrade = true
                        } label: {
                            Label("광고 연장 / 영구 사용", systemImage: "sparkles")
                                .font(.title3.weight(.semibold))
                                .frame(maxWidth: 420)
                                .frame(height: MonitorTheme.secondaryButtonHeight)
                        }
                        .buttonStyle(.bordered)
                        .tint(Color.monitorPrimary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("쉽게 쓰는 순서")
                        .font(.headline)
                    ForEach(MonitorRole.pad.steps, id: \.0) { step in
                        MonitorGuideStep(number: step.0, title: step.1, detail: step.2)
                    }
                }

                if !usageAccess.lifetimeUnlocked && adsMayLoad {
                    BannerAdView()
                }

                HStack {
                    Spacer()
                    Button("사용법 다시 보기") {
                        showingUsageGuide = true
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
            .padding(MonitorTheme.pagePadding)
        }
        .background(MonitorBackground())
    }

    private func watchAd() {
        Task {
            do {
                try await ads.showRewarded()
                MonetizationApplier.apply(.rewardedAdFinished, to: usageAccess)
                showingUpgrade = false
            } catch {
                ads.status = error.localizedDescription
            }
        }
    }

    private func syncPurchaseState() {
        guard store.didRefreshEntitlements else { return }
        usageAccess.setLifetimeEntitlement(store.hasLifetimeEntitlement)
        BroadcastSharedSettings.cacheVerifiedLifetimeEntitlement(store.hasLifetimeEntitlement)
    }
}
