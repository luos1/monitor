import Combine
import SwiftUI

private final class ReceiverDisplayMode: ObservableObject {
    @Published var isFullWindowMirror = false
}

struct ReceiverView: View {
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var receiver = FrameReceiver()
    @StateObject private var displayMode = ReceiverDisplayMode()

    var body: some View {
        Group {
            if displayMode.isFullWindowMirror {
                fullWindowMirrorView
            } else {
                splitMirrorView
            }
        }
        .frame(minWidth: 900, minHeight: 600)
        .onAppear {
            browser.startSearching()
        }
        .onDisappear {
            receiver.disconnect()
            browser.stopSearching()
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
                Text("iPad 현재 화면")
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
                    description: Text("iPad 앱에서 ‘iPad Mirror Broadcast’ 화면 방송을 시작한 뒤 새로고침하세요.")
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
}
