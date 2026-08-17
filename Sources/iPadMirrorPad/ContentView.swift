import SwiftUI

struct ContentView: View {
    @AppStorage("monitor.pad.didShowUsageGuide") private var didShowUsageGuide = false
    @State private var showingUsageGuide = false
    @StateObject private var usageAccess = UsageAccessManager(namespace: "monitor.pad")
    @StateObject private var broadcast = BroadcastControllerModel()

    private var broadcastExtensionIdentifier: String {
        "\(Bundle.main.bundleIdentifier ?? "dev.local.iPadMirrorPad").BroadcastExtension"
    }

    var body: some View {
        Group {
            if usageAccess.isLocked {
                MonitorPaywallView(
                    remainingLabel: usageAccess.remainingTimeLabel,
                    onWatchAd: { usageAccess.grantAdExtension(minutes: MonitorTheme.freeMinutes) },
                    onShowGuide: { showingUsageGuide = true }
                )
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
        .onAppear {
            usageAccess.startTracking()
        }
        .onDisappear {
            usageAccess.stopTracking()
        }
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
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("쉽게 쓰는 순서")
                        .font(.headline)
                    ForEach(MonitorRole.pad.steps, id: \.0) { step in
                        MonitorGuideStep(number: step.0, title: step.1, detail: step.2)
                    }
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
}
