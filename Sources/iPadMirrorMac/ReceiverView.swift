import Combine
import SwiftUI
import iPadMirrorShared

private final class ReceiverDisplayMode: ObservableObject {
    @Published var isFullWindowMirror = false
}

struct ReceiverView: View {
    @AppStorage("monitor.mac.didShowUsageGuide") private var didShowUsageGuide = false
    @State private var showingUsageGuide = false
    @State private var showingUpgrade = false
    @StateObject private var usageAccess = UsageAccessManager(namespace: "monitor.mac")
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var receiver = FrameReceiver()
    @StateObject private var displayMode = ReceiverDisplayMode()
    @StateObject private var store = StorePurchaseManager()
    @StateObject private var ads = MacAdRewardController()

    var body: some View {
        Group {
            if usageAccess.isLocked {
                paywall(title: "무료 \(MonitorTheme.freeMinutes)분이 끝났어요")
            } else if didShowUsageGuide {
                mainContent
            } else {
                MonitorOnboardingView(role: .mac) {
                    didShowUsageGuide = true
                }
            }
        }
        .frame(minWidth: 960, minHeight: 640)
        .background(MonitorBackground())
        .sheet(isPresented: $showingUsageGuide) {
            MonitorOnboardingView(role: .mac) {
                didShowUsageGuide = true
                showingUsageGuide = false
            }
            .frame(minWidth: 720, minHeight: 740)
        }
        .sheet(isPresented: $showingUpgrade) {
            paywall(title: "유료 기능")
                .frame(minWidth: 720, minHeight: 740)
        }
        .onReceive(NotificationCenter.default.publisher(for: .monitorShowUsageGuide)) { _ in
            showingUsageGuide = true
        }
        .onChange(of: store.hasLifetimeEntitlement) { _, unlocked in
            if unlocked {
                MonetizationApplier.apply(.lifetimeUnlocked, to: usageAccess)
            }
        }
        .onAppear {
            browser.startSearching()
            usageAccess.startTracking()
            store.start()
            ads.start()
            if store.hasLifetimeEntitlement {
                MonetizationApplier.apply(.lifetimeUnlocked, to: usageAccess)
            }
        }
        .onDisappear {
            receiver.disconnect()
            browser.stopSearching()
            usageAccess.stopTracking()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            if displayMode.isFullWindowMirror {
                fullWindowMirrorView
            } else {
                splitMirrorView
            }
        }
    }

    private var splitMirrorView: some View {
        HSplitView {
            deviceListView
                .frame(minWidth: 300, idealWidth: 340, maxWidth: 400)

            VStack(spacing: 16) {
                headerBar

                MonitorCompanionBanner(role: .mac)
                    .padding(.horizontal, 20)

                mirrorBezel
                    .padding(.horizontal, 20)

                footerBar
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            MonitorBrandMark(size: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(MonitorTheme.brandName)
                    .font(.title3.weight(.semibold))
                Text(receiver.image == nil ? "화면을 기다리는 중" : "미러링 연결됨")
                    .font(.caption)
                    .foregroundStyle(receiver.image == nil ? Color.monitorOnSurfaceVariant : Color.monitorSuccess)
            }
            Spacer()
            MonitorUsageChip(
                remainingSeconds: usageAccess.remainingSeconds,
                lifetimeUnlocked: usageAccess.lifetimeUnlocked,
                remainingLabel: usageAccess.remainingTimeLabel
            )
        }
        .padding(.horizontal, 20)
    }

    private var footerBar: some View {
        HStack {
            Text(receiver.status)
                .font(.caption)
                .foregroundStyle(Color.monitorOnSurfaceVariant)
                .lineLimit(1)

            Spacer()

            Button("사용법") {
                showingUsageGuide = true
            }

            if !usageAccess.lifetimeUnlocked {
                Button("유료 기능") {
                    showingUpgrade = true
                }
            }

            Button("앱 전체 크기로 보기") {
                displayMode.isFullWindowMirror = true
            }
            .disabled(receiver.image == nil)
            .keyboardShortcut("f", modifiers: [.command, .shift])
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("연결된 iPad")
                        .font(.headline)
                    Text(browser.status)
                        .font(.caption)
                        .foregroundStyle(Color.monitorOnSurfaceVariant)
                }
                Spacer()
                Button {
                    browser.restartSearching()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("새로고침")
            }

            if browser.devices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "ipad.and.arrow.forward")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.monitorPrimary)
                    Text("방송 중인 iPad 없음")
                        .font(.headline)
                    Text("iPad 앱에서 방송을 시작하면 여기에 나타납니다.")
                        .font(.subheadline)
                        .foregroundStyle(Color.monitorOnSurfaceVariant)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(browser.devices) { device in
                            Button {
                                receiver.connect(to: device)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "ipad")
                                        .font(.title3.weight(.semibold))
                                        .foregroundStyle(Color.monitorPrimary)
                                        .frame(width: 36, height: 36)
                                        .background(Color.monitorPrimaryContainer, in: Circle())

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(device.name)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(Color.monitorOnSurface)
                                        Text(device.endpointDescription)
                                            .font(.caption)
                                            .foregroundStyle(Color.monitorOnSurfaceVariant)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color.monitorOnSurfaceVariant)
                                }
                                .padding(14)
                                .background(Color.monitorSurfaceContainer, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                        .stroke(Color.monitorOutline, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.72))
    }

    private var mirrorBezel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: MonitorTheme.bezelRadius, style: .continuous)
                .fill(Color.monitorCanvas)

            if let image = receiver.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(8)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "display")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.72))
                    Text("현재 화면 미러링 대기 중")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("왼쪽 목록에서 iPad 이름을 선택하세요.")
                        .font(.subheadline)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .shadow(color: Color.black.opacity(0.18), radius: 18, y: 8)
    }

    private var fullWindowMirrorView: some View {
        ZStack(alignment: .topTrailing) {
            Color.monitorCanvas.ignoresSafeArea()

            if let image = receiver.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                mirrorBezel
            }

            HStack(spacing: 12) {
                Text(receiver.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                MonitorUsageChip(
                    remainingSeconds: usageAccess.remainingSeconds,
                    lifetimeUnlocked: usageAccess.lifetimeUnlocked,
                    remainingLabel: usageAccess.remainingTimeLabel
                )

                Button("사용법") {
                    showingUsageGuide = true
                }

                Button("목록 보기") {
                    displayMode.isFullWindowMirror = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding()
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
            onWatchAd: {
                Task {
                    do {
                        try await ads.showRewarded()
                    } catch {
                        ads.status = error.localizedDescription
                    }
                }
            },
            onShowGuide: { showingUsageGuide = true }
        )
    }
}
