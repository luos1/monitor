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
                usageLockedView
            } else if didShowUsageGuide {
                mainContent
            } else {
                usageGuideView
            }
        }
        .sheet(isPresented: $showingUsageGuide) {
            usageGuideView
        }
        .onAppear {
            usageAccess.startTracking()
        }
        .onDisappear {
            usageAccess.stopTracking()
        }
    }

    private var mainContent: some View {
        VStack(spacing: 24) {
            Image(systemName: broadcast.isBroadcasting ? "dot.radiowaves.left.and.right" : "ipad.and.iphone")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 128, height: 128)
                .foregroundColor(broadcast.isBroadcasting ? .red : .accentColor)

            VStack(spacing: 10) {
                Text("아이패드미러")
                    .font(.largeTitle)
                    .fontWeight(.semibold)

                Text("이 iPad 앱은 화면을 보내는 역할입니다. Mac 앱이 함께 켜져 있어야 실제 미러링 화면이 보입니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            dependencyWarningBanner

            VStack(spacing: 14) {
                BroadcastPickerButton(preferredExtension: broadcastExtensionIdentifier)
                    .frame(width: 360, height: 88)
                    .shadow(color: .red.opacity(0.25), radius: 14, y: 6)
                    .accessibilityLabel("전체 화면 공유 시작")

                Button {
                    broadcast.stopBroadcast()
                } label: {
                    Label("화면 공유 종료", systemImage: "stop.circle.fill")
                        .font(.title2.weight(.semibold))
                        .frame(width: 360, height: 64)
                }
                .buttonStyle(.bordered)
                .tint(.gray)
            }

            Text(broadcast.status)
                .font(.headline)
                .foregroundStyle(broadcast.isBroadcasting ? .red : .secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 8) {
                Text("쉽게 쓰는 순서")
                    .font(.headline)
                Text("1. Mac 앱을 먼저 켭니다.")
                Text("2. iPad 앱에서 ‘전체 화면 공유 시작’을 누릅니다.")
                Text("3. 방송 선택창에서 시작하면 Mac 앱에 화면이 나타납니다.")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)

            HStack {
                Spacer()
                Button("사용법 다시 보기") {
                    showingUsageGuide = true
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding(32)
    }

    private var usageGuideView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("아이패드미러 사용법")
                    .font(.largeTitle.weight(.semibold))

                Text("이 앱은 Mac 앱과 같이 써야 완성됩니다. iPad는 화면을 보내고, Mac은 그 화면을 받아 보여줍니다.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                dependencyWarningBanner

                GuideStepCard(number: "1", title: "Mac 앱 먼저 켜기", detail: "Mac 앱이 미러링 받을 준비를 해야 iPad 화면이 보입니다.")
                GuideStepCard(number: "2", title: "iPad에서 방송 시작", detail: "아래 시작 버튼을 누르면 방송 선택창이 뜹니다. 거기서 ‘아이패드미러 방송’을 시작하세요.")
                GuideStepCard(number: "3", title: "Mac에서 장치 선택", detail: "Mac 앱 왼쪽 목록에서 iPad를 선택하면 화면이 연결됩니다.")

                VStack(alignment: .leading, spacing: 8) {
                    Text("중요")
                        .font(.headline)
                    Text("iPad 앱만 또는 Mac 앱만 켜서는 완성되지 않습니다. 둘 다 필요합니다.")
                    Text("나중에 마켓 등록이 끝나면 설치/소개 URL을 이 안내와 버튼 옆에 추가할 예정입니다.")
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
        .frame(minWidth: 640, minHeight: 720)
    }

    private var dependencyWarningBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title2)

            VStack(alignment: .leading, spacing: 6) {
                Text("이 앱은 Mac 앱이 함께 있어야 제대로 작동합니다")
                    .font(.headline)
                Text("iPad 앱은 화면을 보내는 역할만 합니다. Mac 앱이 받아서 보여주지 않으면 화면이 안 보입니다.")
                Text("마켓 등록 후에는 설치/소개 URL을 이 안내와 버튼 옆에 추가할 예정입니다.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
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
