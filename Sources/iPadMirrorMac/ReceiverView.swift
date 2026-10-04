import Combine
import SwiftUI
import iPadMirrorShared

private final class ReceiverDisplayMode: ObservableObject {
    @Published var isFullWindowMirror = false
}

struct ReceiverView: View {
    @AppStorage("monitor.mac.didShowUsageGuide") private var didShowUsageGuide = false
    @State private var showingUsageGuide = false
    @State private var pairingCode = ""
    @StateObject private var browser = BonjourBrowser()
    @StateObject private var receiver = FrameReceiver()
    @StateObject private var displayMode = ReceiverDisplayMode()
    #if DEBUG
    @State private var qaConnectionTask: Task<Void, Never>?
    @State private var qaFrameCount = 0
    #endif

    var body: some View {
        Group {
            if didShowUsageGuide {
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
        .onReceive(NotificationCenter.default.publisher(for: .monitorShowUsageGuide)) { _ in
            showingUsageGuide = true
        }
        .onAppear {
            browser.startSearching()
            #if DEBUG
            preparePhysicalQA()
            #endif
        }
        #if DEBUG
        .onReceive(receiver.$image) { image in recordPhysicalQAFrame(image) }
        #endif
        .onDisappear {
            #if DEBUG
            qaConnectionTask?.cancel()
            qaConnectionTask = nil
            #endif
            receiver.disconnect()
            browser.stopSearching()
        }
    }

    #if DEBUG
    // Local QA only. Release has no automatic connection or file output.
    private var qaConfiguration: [String: String]? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-PhysicalQAConfig"), index + 1 < arguments.count,
              let data = try? Data(contentsOf: URL(fileURLWithPath: arguments[index + 1])),
              let configuration = try? JSONDecoder().decode([String: String].self, from: data),
              configuration["pairingCode"]?.count == 8 else { return nil }
        return configuration
    }

    private func preparePhysicalQA() {
        guard let configuration = qaConfiguration, qaConnectionTask == nil else { return }
        didShowUsageGuide = true
        if configuration["fullWindow"] == "true" { displayMode.isFullWindowMirror = true }
        pairingCode = configuration["pairingCode"] ?? ""
        qaConnectionTask = Task { @MainActor in
            for _ in 0..<180 {
                guard !Task.isCancelled, receiver.image == nil else { return }
                if let host = configuration["host"], let port = Int(configuration["port"] ?? "12346") {
                    receiver.connect(host: host, port: port, pairingCode: pairingCode)
                } else if let serial = configuration["deviceSerial"] {
                    let devices = await Task.detached { (try? UsbMuxClient.listDevices()) ?? [] }.value
                    if let device = devices.first(where: { $0.serialNumber.replacingOccurrences(of: "-", with: "") == serial.replacingOccurrences(of: "-", with: "") }) {
                        receiver.connect(to: BonjourBrowser.Device(usb: device, port: 12346), pairingCode: pairingCode)
                    }
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private func recordPhysicalQAFrame(_ image: NSImage?) {
        guard let image, let configuration = qaConfiguration,
              let output = configuration["evidencePath"],
              let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return }
        qaFrameCount += 1
        let record: [String: Any] = [
            "checked_at_utc": ISO8601DateFormatter().string(from: Date()),
            "transport": configuration["host"] == nil ? "USB" : "network",
            "authenticated_decoded_frames": qaFrameCount,
            "width": cgImage.width, "height": cgImage.height,
            "screen_image_saved": false, "pairing_code_exposed": false,
            "scope": "actual Debug Mac receiver view; encrypted JPEG decoded from physical iPad"
        ]
        if let data = try? JSONSerialization.data(withJSONObject: record, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: output), options: .atomic)
        }
    }
    #endif

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
                Text(receiver.image == nil ? MirrorL10n.text("화면을 기다리는 중") : MirrorL10n.text("미러링 연결됨"))
                    .font(.caption)
                    .foregroundStyle(receiver.image == nil ? Color.monitorOnSurfaceVariant : Color.monitorSuccess)
            }
            Spacer()
            freeCompanionLabel
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

            Button {
                showingUsageGuide = true
            } label: {
                Text(MirrorL10n.text("사용법")).foregroundStyle(Color.black)
            }

            Button {
                displayMode.isFullWindowMirror = true
            } label: {
                Text(MirrorL10n.text("앱 전체 크기로 보기")).foregroundStyle(Color.black)
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
                    Text(MirrorL10n.text("연결된 iPad"))
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
                .help(MirrorL10n.text("새로고침"))
            }

            SecureField(MirrorL10n.text("iPad 연결 코드 (예: ABCD-2345)"), text: $pairingCode)
                .textFieldStyle(.roundedBorder)
                .help(MirrorL10n.text("iPad 앱 홈 화면에 표시된 8자리 코드를 입력하세요."))

            if browser.devices.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "ipad.and.arrow.forward")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.monitorPrimary)
                    Text(MirrorL10n.text("방송 중인 iPad 없음"))
                        .font(.headline)
                    Text(MirrorL10n.text("iPad 앱에서 방송을 시작하면 여기에 나타납니다."))
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
                                receiver.connect(to: device, pairingCode: pairingCode)
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
                    Text(MirrorL10n.text("현재 화면 미러링 대기 중"))
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(MirrorL10n.text("왼쪽 목록에서 iPad 이름을 선택하세요."))
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

                freeCompanionLabel

                Button {
                    showingUsageGuide = true
                } label: {
                    Text(MirrorL10n.text("사용법")).foregroundStyle(Color.black)
                }

                Button(MirrorL10n.text("목록 보기")) {
                    displayMode.isFullWindowMirror = false
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding()
        }
    }

    private var freeCompanionLabel: some View {
        Label(MirrorL10n.text("무료 동반 앱"), systemImage: "infinity")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.monitorPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.monitorPrimary.opacity(0.12), in: Capsule())
    }
}
