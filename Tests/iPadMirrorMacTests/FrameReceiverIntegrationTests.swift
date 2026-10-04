import XCTest
import AppKit
import CryptoKit
import Network
@testable import iPadMirrorMac
import iPadMirrorShared

/// Loopback protocol/receiver tests; hardware tests are reported separately.
@MainActor
final class FrameReceiverIntegrationTests: XCTestCase {
    func testEncryptedJPEGConnectDisconnectAndReconnect() async throws {
        let first = try LoopbackBroadcast(jpegWidth: 120, jpegHeight: 80)
        defer { first.stop() }
        let port = try await first.readyPort()
        let receiver = FrameReceiver()
        receiver.connect(host: "127.0.0.1", port: port, pairingCode: "abcd-2345")
        try await wait { receiver.image != nil }
        XCTAssertTrue(first.authenticated)
        XCTAssertTrue(receiver.status.contains(MirrorL10n.text(MacDistribution.isNetworkOnly ? "네트워크" : "유선 최적화")))
        XCTAssertEqual(try dimensions(receiver.image!).width, 120)
        receiver.disconnect()
        XCTAssertNil(receiver.image)
        XCTAssertEqual(receiver.status, MirrorL10n.text("연결 해제"))

        let second = try LoopbackBroadcast(jpegWidth: 80, jpegHeight: 120)
        defer { second.stop() }
        receiver.connect(host: "127.0.0.1", port: try await second.readyPort(), pairingCode: "ABCD2345")
        try await wait { receiver.image != nil }
        let size = try dimensions(receiver.image!)
        XCTAssertEqual(size.width, 80)
        XCTAssertEqual(size.height, 120)
        receiver.disconnect()
    }

    func testWrongPairingCodeDoesNotDisplayAFrame() async throws {
        let server = try LoopbackBroadcast()
        defer { server.stop() }
        let receiver = FrameReceiver()
        receiver.connect(host: "127.0.0.1", port: try await server.readyPort(), pairingCode: "ZZZZ9999")
        try await wait { receiver.status == MirrorL10n.text("iPad가 연결을 종료했습니다") }
        XCTAssertNil(receiver.image)
        XCTAssertFalse(server.authenticated)
    }

    func testOversizedFrameIsRejectedBeforeReadingBody() async throws {
        let server = try LoopbackBroadcast(mode: .oversized)
        defer { server.stop() }
        let receiver = FrameReceiver()
        receiver.connect(host: "127.0.0.1", port: try await server.readyPort(), pairingCode: "ABCD2345")
        let expected = MirrorL10n.format("잘못된 프레임 크기: {0} bytes", String(21 * 1024 * 1024))
        try await wait { receiver.status == expected }
        XCTAssertNil(receiver.image)
    }

    func testUnauthenticatedFrameIsRejected() async throws {
        let server = try LoopbackBroadcast(mode: .wrongEncryptionKey)
        defer { server.stop() }
        let receiver = FrameReceiver()
        receiver.connect(host: "127.0.0.1", port: try await server.readyPort(), pairingCode: "ABCD2345")
        try await wait { receiver.status == MirrorL10n.text("프레임 인증 또는 이미지 디코딩 실패") }
        XCTAssertNil(receiver.image)
    }

    func testOldConnectionCannotReplaceNewImageOrStatus() async throws {
        let old = try LoopbackBroadcast(jpegWidth: 240, jpegHeight: 80, delay: 0.4)
        let new = try LoopbackBroadcast(jpegWidth: 80, jpegHeight: 160)
        defer { old.stop(); new.stop() }
        let receiver = FrameReceiver()
        receiver.connect(host: "127.0.0.1", port: try await old.readyPort(), pairingCode: "ABCD2345")
        try await wait { old.authenticated }
        receiver.connect(host: "127.0.0.1", port: try await new.readyPort(), pairingCode: "ABCD2345")
        try await wait { receiver.image != nil }
        try await Task.sleep(for: .milliseconds(650))
        XCTAssertEqual(try dimensions(receiver.image!).width, 80)
        XCTAssertTrue(receiver.status.contains(MirrorL10n.text(MacDistribution.isNetworkOnly ? "네트워크" : "유선 최적화")))
        receiver.disconnect()
    }

    func testInvalidPairingCodeAndPortAreHandledWithoutConnection() {
        let receiver = FrameReceiver()
        receiver.connect(host: "127.0.0.1", port: 12346, pairingCode: "bad")
        XCTAssertEqual(receiver.status, MirrorL10n.text("iPad에 표시된 8자리 연결 코드를 입력하세요"))
        receiver.connect(host: "127.0.0.1", port: -1, pairingCode: "ABCD2345")
        XCTAssertEqual(receiver.status, MirrorL10n.format("잘못된 포트: {0}", "-1"))
        XCTAssertNil(receiver.image)
    }

    private func dimensions(_ image: NSImage) throws -> (width: Int, height: Int) {
        let cg = try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
        return (cg.width, cg.height)
    }

    private func wait(_ condition: () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(30))
        }
        XCTFail("Receiver state did not reach the expected result within three seconds.")
        throw NSError(domain: "iPadMirrorQA", code: 1)
    }
}

private final class LoopbackBroadcast: @unchecked Sendable {
    enum Mode { case valid, oversized, wrongEncryptionKey }
    private let queue = DispatchQueue(label: "iPadMirrorQA.Loopback")
    private let lock = NSLock()
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private var _port: Int?
    private var _authenticated = false
    private let mode: Mode
    private let delay: TimeInterval
    private let jpeg: Data
    private let challenge = Data(repeating: 42, count: 32)
    private let key = SymmetricKey(data: SHA256.hash(data: Data("ABCD2345".utf8)))

    var authenticated: Bool { lock.lock(); defer { lock.unlock() }; return _authenticated }
    private var port: Int? { lock.lock(); defer { lock.unlock() }; return _port }

    init(jpegWidth: Int = 120, jpegHeight: Int = 80, mode: Mode = .valid, delay: TimeInterval = 0) throws {
        self.mode = mode
        self.delay = delay
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: jpegWidth, pixelsHigh: jpegHeight, bitsPerSample: 8, samplesPerPixel: 3, hasAlpha: false, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        memset(bitmap.bitmapData!, 160, bitmap.bytesPerRow * bitmap.pixelsHigh)
        self.jpeg = try XCTUnwrap(bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.5]))
        listener = try NWListener(using: .tcp, on: .any)
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state, let port = self.listener.port {
                self.lock.lock(); self._port = Int(port.rawValue); self.lock.unlock()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.start(queue: queue)
    }

    func readyPort() async throws -> Int {
        for _ in 0..<100 {
            if let port { return port }
            try await Task.sleep(for: .milliseconds(20))
        }
        throw NSError(domain: "iPadMirrorQA", code: 2)
    }

    func stop() {
        listener.cancel()
        queue.sync { connections.forEach { $0.cancel() }; connections.removeAll() }
    }

    private func accept(_ connection: NWConnection) {
        connections.append(connection)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            if case .ready = state {
                let message = Data("CHALLENGE \(self.challenge.base64EncodedString())\n".utf8)
                connection.send(content: message, completion: .contentProcessed { [weak self, weak connection] error in
                    guard error == nil, let self, let connection else { return }
                    self.readAuthentication(connection)
                })
            }
        }
        connection.start(queue: queue)
    }

    private func readAuthentication(_ connection: NWConnection, buffer: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 256) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection, error == nil, let data else { return }
            var received = buffer; received.append(data)
            let expectedProfile = MacDistribution.isNetworkOnly ? "wireless" : "wired"
            if !received.contains(Data("\nPROFILE \(expectedProfile)\n".utf8)) {
                if !isComplete { self.readAuthentication(connection, buffer: received) }
                return
            }
            let expected = Data(HMAC<SHA256>.authenticationCode(for: self.challenge, using: self.key))
            guard String(decoding: received, as: UTF8.self).hasPrefix("AUTH \(expected.base64EncodedString())\n") else {
                connection.cancel()
                return
            }
            self.lock.lock(); self._authenticated = true; self.lock.unlock()
            self.queue.asyncAfter(deadline: .now() + self.delay) {
                var packet = Data()
                if self.mode == .oversized {
                    var length = UInt32(21 * 1024 * 1024).bigEndian
                    packet.append(Data(bytes: &length, count: 4))
                } else {
                    let key = self.mode == .wrongEncryptionKey ? SymmetricKey(size: .bits256) : self.key
                    guard let sealed = try? ChaChaPoly.seal(self.jpeg, using: key) else { return }
                    var length = UInt32(sealed.combined.count).bigEndian
                    packet.append(Data(bytes: &length, count: 4)); packet.append(sealed.combined)
                }
                connection.send(content: packet, completion: .contentProcessed { _ in })
            }
        }
    }
}
