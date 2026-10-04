import iPadMirrorShared
import AppKit
import Combine
import CryptoKit
import Darwin
import Foundation
import ImageIO
import Network

// Connection/session state is guarded by sessionLock. Published UI values and
// frame counts are written only on the main queue; decoding uses serial workers.
final class FrameReceiver: ObservableObject, @unchecked Sendable {
    @Published private(set) var image: NSImage?
    @Published private(set) var status = MirrorL10n.text("iPad를 선택하세요")

    private final class Session: @unchecked Sendable {
        let key: SymmetricKey
        var connection: NWConnection?
        var socket: Int32?
        var transportLabel: String
        // Image/count updates only run on the main queue.
        var frameCount = 0
        init(code: String, transportLabel: String) {
            self.key = FrameReceiver.pairingKey(for: code)
            self.transportLabel = transportLabel
        }
    }

    private let queue = DispatchQueue(label: "dev.local.iPadMirrorMac.FrameReceiver", qos: .userInitiated)
    private let usbQueue = DispatchQueue(label: "dev.local.iPadMirrorMac.USBFrameReceiver", qos: .userInitiated)
    private let sessionLock = NSLock()
    private var currentSession: Session?
    private let maxFrameSize = 20 * 1024 * 1024
    private let maxImageDimension = 4_096
    private let maxImagePixelCount = 16_777_216

    @MainActor
    func connect(to device: BonjourBrowser.Device, pairingCode: String) {
        if let deviceID = device.usbDeviceID {
            connectUSB(deviceID: deviceID, port: device.port, displayName: device.name, pairingCode: pairingCode)
        } else {
            connect(host: device.host, port: device.port, pairingCode: pairingCode)
        }
    }

    @MainActor
    func connect(host: String, port: Int, pairingCode: String) {
        disconnect()
        let code = Self.normalizedPairingCode(pairingCode)
        guard code.count == 8 else {
            status = MirrorL10n.text("iPad에 표시된 8자리 연결 코드를 입력하세요")
            return
        }
        guard let rawPort = UInt16(exactly: port), rawPort > 0,
              let nwPort = NWEndpoint.Port(rawValue: rawPort) else {
            status = MirrorL10n.format("잘못된 포트: {0}", String(port))
            return
        }
        let session = Session(code: code, transportLabel: MirrorL10n.text("네트워크"))
        let tcp = NWProtocolTCP.Options()
        tcp.noDelay = true
        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: NWParameters(tls: nil, tcp: tcp))
        session.connection = connection
        sessionLock.lock()
        currentSession = session
        sessionLock.unlock()
        status = MirrorL10n.format("{0}:{1}에 연결 중…", host, String(port))
        connection.stateUpdateHandler = { [weak self, weak session, weak connection] state in
            guard let self, let session, let connection, self.isCurrent(session) else { return }
            self.handle(state, connection: connection, session: session)
        }
        connection.start(queue: queue)
    }

    @MainActor
    func disconnect() {
        abortCurrentSession()
        image = nil
        status = MirrorL10n.text("연결 해제")
    }

    deinit { abortCurrentSession() }

    private func abortCurrentSession() {
        sessionLock.lock()
        let previous = currentSession
        currentSession = nil
        let connection = previous?.connection
        let socket = previous?.socket
        if let socket {
            // The read worker owns close(). Shutdown interrupts a blocked read
            // without letting a stale worker close a reused file descriptor.
            Darwin.shutdown(socket, SHUT_RDWR)
        }
        sessionLock.unlock()
        connection?.cancel()
    }

    private func isCurrent(_ session: Session) -> Bool {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return currentSession === session
    }

    @MainActor
    private func connectUSB(deviceID: Int, port: Int, displayName: String, pairingCode: String) {
        disconnect()
        let code = Self.normalizedPairingCode(pairingCode)
        guard code.count == 8 else {
            status = MirrorL10n.text("iPad에 표시된 8자리 연결 코드를 입력하세요")
            return
        }
        guard let port = UInt16(exactly: port), port > 0 else {
            status = MirrorL10n.format("잘못된 포트: {0}", String(port))
            return
        }
        let session = Session(code: code, transportLabel: MirrorL10n.text("USB 직접 연결"))
        sessionLock.lock()
        currentSession = session
        sessionLock.unlock()
        status = MirrorL10n.format("{0} USB 연결 중…", displayName)

        usbQueue.async { [weak self, session] in
            guard let self, self.isCurrent(session) else { return }
            do {
                let socket = try UsbMuxClient.connectToDevice(deviceID: deviceID, port: port)
                defer {
                    self.sessionLock.lock()
                    if session.socket == socket { session.socket = nil }
                    close(socket)
                    self.sessionLock.unlock()
                }
                self.sessionLock.lock()
                let active = self.currentSession === session
                if active { session.socket = socket }
                self.sessionLock.unlock()
                guard active else { return }
                let challenge = try self.readChallenge(from: socket)
                try UsbMuxClient.writeAll(self.authenticationMessage(challenge: challenge, key: session.key), to: socket)
                // Handshake is bounded; a live stream may pause indefinitely.
                try UsbMuxClient.setReadTimeout(socket: socket, seconds: 0)
                self.publishStatus(MirrorL10n.text("연결 코드를 확인하는 중…"), session: session)
                self.receiveUSBFrames(from: socket, session: session)
            } catch {
                self.fail(MirrorL10n.format("USB 연결 실패: {0}", MirrorL10n.errorMessage(error)), session: session)
            }
        }
    }

    private func handle(_ state: NWConnection.State, connection: NWConnection, session: Session) {
        switch state {
        case .ready:
            let actual = connection.currentPath.map(Self.transportLabel(for:)) ?? MirrorL10n.text("네트워크")
            sessionLock.lock()
            session.transportLabel = actual
            sessionLock.unlock()
            receiveChallenge(from: connection, session: session)
        case .waiting(let error):
            publishStatus(MirrorL10n.format("연결 대기 중: {0}", MirrorL10n.errorMessage(error)), session: session)
        case .failed(let error):
            fail(MirrorL10n.format("연결 실패: {0}", MirrorL10n.errorMessage(error)), session: session)
        default:
            break
        }
    }

    private func receiveChallenge(from connection: NWConnection, session: Session, buffer: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 128) { [weak self, weak session, weak connection] data, _, isComplete, error in
            guard let self, let session, let connection, self.isCurrent(session) else { return }
            var received = buffer
            if let data { received.append(data) }
            guard error == nil, received.count <= 128 else {
                self.fail(MirrorL10n.text("iPad 연결 인증 요청이 올바르지 않습니다"), session: session)
                return
            }
            guard received.contains(0x0A) else {
                if isComplete {
                    self.fail(MirrorL10n.text("iPad 연결 인증 요청이 올바르지 않습니다"), session: session)
                } else {
                    self.receiveChallenge(from: connection, session: session, buffer: received)
                }
                return
            }
            guard let challenge = self.parseChallenge(received) else {
                self.fail(MirrorL10n.text("iPad 연결 인증 요청이 올바르지 않습니다"), session: session)
                return
            }
            connection.send(content: self.authenticationMessage(challenge: challenge, key: session.key), completion: .contentProcessed { [weak self, weak session, weak connection] error in
                guard let self, let session, let connection, self.isCurrent(session) else { return }
                if let error {
                    self.fail(MirrorL10n.format("연결 인증 전송 실패: {0}", MirrorL10n.errorMessage(error)), session: session)
                    return
                }
                self.publishStatus(MirrorL10n.text("연결 코드를 확인하는 중…"), session: session)
                self.receiveHeader(from: connection, session: session)
            })
        }
    }

    private func receiveHeader(from connection: NWConnection, session: Session) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self, weak session, weak connection] data, _, isComplete, error in
            guard let self, let session, let connection, self.isCurrent(session) else { return }
            if let error {
                self.fail(MirrorL10n.format("헤더 수신 오류: {0}", MirrorL10n.errorMessage(error)), session: session)
                return
            }
            guard let data, data.count == 4 else {
                self.fail(MirrorL10n.text(isComplete ? "iPad가 연결을 종료했습니다" : "잘못된 프레임 헤더"), session: session)
                return
            }
            let length = self.decodeFrameLength(data)
            guard length > 0, length <= self.maxFrameSize else {
                self.fail(MirrorL10n.format("잘못된 프레임 크기: {0} bytes", String(length)), session: session)
                return
            }
            self.receiveFrame(length: length, from: connection, session: session)
        }
    }

    private func receiveFrame(length: Int, from connection: NWConnection, session: Session) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self, weak session, weak connection] data, _, isComplete, error in
            guard let self, let session, let connection, self.isCurrent(session) else { return }
            if let error {
                self.fail(MirrorL10n.format("프레임 수신 오류: {0}", MirrorL10n.errorMessage(error)), session: session)
                return
            }
            guard let data, data.count == length else {
                self.fail(MirrorL10n.text(isComplete ? "iPad가 연결을 종료했습니다" : "프레임 크기 불일치"), session: session)
                return
            }
            guard self.displayFrame(data, session: session) else {
                self.fail(MirrorL10n.text("프레임 인증 또는 이미지 디코딩 실패"), session: session)
                return
            }
            self.receiveHeader(from: connection, session: session)
        }
    }

    private func receiveUSBFrames(from socket: Int32, session: Session) {
        while isCurrent(session) {
            do {
                let header = try UsbMuxClient.readExact(from: socket, byteCount: 4)
                let length = decodeFrameLength(header)
                guard length > 0, length <= maxFrameSize else {
                    fail(MirrorL10n.format("USB 프레임 크기 오류: {0} bytes", String(length)), session: session)
                    return
                }
                let data = try UsbMuxClient.readExact(from: socket, byteCount: length)
                guard displayFrame(data, session: session) else {
                    fail(MirrorL10n.text("USB 프레임 인증 또는 이미지 디코딩 실패"), session: session)
                    return
                }
            } catch {
                fail(MirrorL10n.format("USB 수신 종료: {0}", MirrorL10n.errorMessage(error)), session: session)
                return
            }
        }
    }

    private func displayFrame(_ data: Data, session: Session) -> Bool {
        guard let box = try? ChaChaPoly.SealedBox(combined: data),
              let decrypted = try? ChaChaPoly.open(box, using: session.key),
              let decoded = decodeValidatedImage(decrypted) else { return false }
        sessionLock.lock()
        let transportLabel = session.transportLabel
        sessionLock.unlock()
        DispatchQueue.main.async { [weak self, weak session] in
            guard let self, let session, self.isCurrent(session) else { return }
            self.image = decoded
            session.frameCount += 1
            if session.frameCount == 1 || session.frameCount % 15 == 0 {
                self.status = MirrorL10n.format("수신 중 · {0} ({1} bytes)", transportLabel, String(data.count))
            }
        }
        return true
    }

    private func publishStatus(_ message: String, session: Session) {
        DispatchQueue.main.async { [weak self, weak session] in
            guard let self, let session, self.isCurrent(session) else { return }
            self.status = message
        }
    }

    private func fail(_ message: String, session: Session) {
        DispatchQueue.main.async { [weak self, weak session] in
            guard let self, let session, self.isCurrent(session) else { return }
            self.abortCurrentSession()
            self.image = nil
            self.status = message
        }
    }

    private func readChallenge(from socket: Int32) throws -> Data {
        var line = Data()
        while line.count < 128 {
            let byte = try UsbMuxClient.readExact(from: socket, byteCount: 1)
            if byte.first == 0x0A {
                guard let challenge = parseChallenge(line) else { throw UsbMuxClient.UsbMuxError.invalidResponse }
                return challenge
            }
            line.append(byte)
        }
        throw UsbMuxClient.UsbMuxError.invalidResponse
    }

    private func parseChallenge(_ data: Data) -> Data? {
        let line = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("CHALLENGE "),
              let challenge = Data(base64Encoded: String(line.dropFirst(10))),
              challenge.count == 32 else { return nil }
        return challenge
    }

    private func authenticationMessage(challenge: Data, key: SymmetricKey) -> Data {
        let authentication = Data(HMAC<SHA256>.authenticationCode(for: challenge, using: key))
        return Data("AUTH \(authentication.base64EncodedString())\nPROFILE wired\n".utf8)
    }

    private func decodeFrameLength(_ data: Data) -> Int {
        data.reduce(0) { ($0 << 8) | Int($1) }
    }

    private func decodeValidatedImage(_ data: Data) -> NSImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetType(source) as String? == "public.jpeg",
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              width > 0, height > 0,
              width <= maxImageDimension, height <= maxImageDimension,
              width <= maxImagePixelCount / height else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxImageDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cgImage, size: .zero)
    }

    private static func pairingKey(for code: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(code.utf8)))
    }

    private static func normalizedPairingCode(_ code: String) -> String {
        code.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    private static func transportLabel(for path: NWPath) -> String {
        if path.usesInterfaceType(.wiredEthernet) || path.usesInterfaceType(.loopback) || path.usesInterfaceType(.other) {
            return MirrorL10n.text("유선 최적화")
        }
        return path.usesInterfaceType(.wifi) ? "Wi‑Fi" : MirrorL10n.text("네트워크")
    }
}
