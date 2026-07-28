import Combine
import SwiftUI

private final class ReceiverDisplayMode: ObservableObject {
    @Published var isFullWindowMirror = false
}

struct ReceiverView: View {
    @AppStorage("monitor.mac.didShowUsageGuide") private var didShowUsageGuide = false
    @State private var showingUsageGuide = false
    @StateObject private var usageAccess = UsageAccessManager(namespace: "monitor.mac")
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var receiver = FrameReceiver()
    @StateObject private var displayMode = ReceiverDisplayMode()

    var body: some View {
        Group {
            if usageAccess.isLocked {
                usageLockedView
            } else if didShowUsageGuide {
                mainContent
            } else {
                usageGuideView
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .sheet(isPresented: $showingUsageGuide) {
            usageGuideView
        }
        .onAppear {
            browser.startSearching()
            usageAccess.startTracking()
        }
        .onDisappear {
            receiver.disconnect()
            browser.stopSearching()
            usageAccess.stopTracking()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 12) {
            dependencyWarningBanner

            Group {
                if displayMode.isFullWindowMirror {
                    fullWindowMirrorView
                } else {
                    splitMirrorView
                }
            }
        }
    }

    private var splitMirrorView: some View {
        HSplitView {
            deviceListView
                .frame(minWidth: 280, idealWidth: 320)
                .padding()

            VStack(spacing: 12) {
                mirrorContentView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack {
                    Text(receiver.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button("사용법") {
                        showingUsageGuide = true
                    }

                    Button("앱 전체 크기로 보기") {
                        displayMode.isFullWindowMirror = true
                    }
                    .disabled(receiver.image == nil)
                    .keyboardShortcut("f", modifiers: [.command, .shift])
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var deviceListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("아이패드미러")
                    .font(.headline)

                Spacer()

                Button("새로고침") {
                    browser.restartSearching()
                }
            }

            if browser.devices.isEmpty {
                ContentUnavailableView(
                    "방송 중인 iPad 없음",
                    systemImage: "ipad.and.arrow.forward",
                    description: Text("iPad 앱에서 방송을 시작해야 이 Mac 앱에 화면이 나타납니다.")
                )
            } else {
                List(browser.devices) { device in
                    Button {
                        receiver.connect(to: device)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(device.name)
                                .font(.body)
                            Text(device.endpointDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
                .listStyle(.sidebar)
            }

            Text(browser.status)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var mirrorContentView: some View {
        ZStack {
            Color.black

            if let image = receiver.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "현재 화면 미러링 대기 중",
                    systemImage: "display",
                    description: Text("왼쪽 목록에서 iPad 이름을 선택하세요.")
                )
                .foregroundStyle(.secondary)
            }
        }
    }

    private var fullWindowMirrorView: some View {
        ZStack(alignment: .topTrailing) {
            mirrorContentView
                .ignoresSafeArea()

            HStack(spacing: 12) {
                Text(receiver.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("사용법") {
                    showingUsageGuide = true
                }

                Button("목록 보기") {
                    displayMode.isFullWindowMirror = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            .padding()
        }
    }

    private var usageLockedView: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 54, weight: .semibold))
                .foregroundStyle(.orange)

            Text("60분 무료 사용이 끝났습니다")
                .font(.largeTitle.weight(.semibold))

            Text("광고를 보면 60분 더 쓸 수 있고, 나중에는 유료 구매와 도네이션 URL도 붙일 예정입니다.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            VStack(spacing: 12) {
                Button {
                    usageAccess.grantAdExtension(minutes: 60)
                } label: {
                    Label("광고 보고 60분 연장", systemImage: "play.rectangle.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 360, height: 60)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    // TODO: 마켓 등록 후 App Store URL 연결
                } label: {
                    Label("영구 사용 구매 URL 대기", systemImage: "cart.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 360, height: 56)
                }
                .buttonStyle(.bordered)

                Button {
                    // TODO: 마켓 등록 후 도네이션 URL 연결
                } label: {
                    Label("도네이션 URL 대기", systemImage: "heart.fill")
                        .font(.title3.weight(.semibold))
                        .frame(width: 360, height: 56)
                }
                .buttonStyle(.bordered)
            }

            Button("사용법 다시 보기") {
                showingUsageGuide = true
            }
            .padding(.top, 8)

            Text("남은 시간: \(usageAccess.remainingSeconds / 60)분")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var usageGuideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("아이패드미러 사용법")
                    .font(.largeTitle.weight(.semibold))

                Text("이 Mac 앱은 iPad가 화면을 보내야만 동작합니다. iPad 앱과 함께 켜야 화면을 받을 수 있습니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                dependencyWarningBanner

                GuideStepCard(number: "1", title: "iPad 앱 먼저 준비", detail: "iPad 앱에서 방송을 시작해야 이 Mac 앱이 화면을 받을 수 있습니다.")
                GuideStepCard(number: "2", title: "장치 목록에서 iPad 선택", detail: "왼쪽 목록에서 보이는 iPad 이름을 누르면 연결이 시작됩니다.")
                GuideStepCard(number: "3", title: "전체 화면 보기", detail: "화면이 잡히면 ‘앱 전체 크기로 보기’로 전환해서 크게 볼 수 있습니다.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("중요")
                        .font(.headline)
                    Text("Mac 앱만 또는 iPad 앱만으로는 완성되지 않습니다. 둘 다 필요합니다.")
                    Text("나중에 마켓 등록이 끝나면 설치/소개 URL을 이 안내에 붙이겠습니다.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 8) {
                    Text("유료/광고")
                        .font(.headline)
                    Text("기본 사용은 60분입니다. 60분이 지나면 전면광고를 보고 사용 시간을 연장할 수 있습니다.")
                    Text("영구 사용 상품은 $4.99, 개발자 응원 도네이션 상품은 $99.99로 넣을 예정입니다.")
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 16))

                Button {
                    didShowUsageGuide = true
                    showingUsageGuide = false
                } label: {
                    Text("시작하기")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(32)
        }
        .frame(minWidth: 700, minHeight: 720)
    }

    private var dependencyWarningBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 6) {
                Text("이 Mac 앱은 iPad 앱이 있어야 화면을 받을 수 있습니다")
                    .font(.headline)
                Text("Mac 앱은 혼자서 화면을 만들지 않습니다. iPad 앱이 보내야 여기에서 보입니다.")
                Text("마켓 등록 후에는 설치/소개 URL을 여기에 추가할 예정입니다.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
    }
}

private struct GuideStepCard: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number)
                .font(.headline)
                .frame(width: 32, height: 32)
                .background(Color.accentColor.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
