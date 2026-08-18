import AppKit
import Combine
import CryptoKit
import Foundation
import Network

final class FrameReceiver: ObservableObject {
    @Published private(set) var image: NSImage?
    @Published private(set) var status = "iPad를 선택하세요"

    private let queue = DispatchQueue(label: "dev.local.iPadMirrorMac.FrameReceiver", qos: .userInitiated)
    private let usbQueue = DispatchQueue(label: "dev.local.iPadMirrorMac.USBFrameReceiver", qos: .userInitiated)
    private let maxFrameSize = 20 * 1024 * 1024
    private var connection: NWConnection?
    private var usbSocket: Int32?
    private var decryptionKey: SymmetricKey?
    private var receivedFrameCount = 0
    private var transportLabel = "네트워크"

    func connect(to device: BonjourBrowser.Device, pairingCode: String) {
        let normalizedCode = Self.normalizedPairingCode(pairingCode)
        guard normalizedCode.count == 8 else {
            status = "iPad에 표시된 8자리 연결 코드를 입력하세요"
            return
        }
        if let usbDeviceID = device.usbDeviceID {
            connectUSB(
                deviceID: usbDeviceID,
                port: device.port,
                displayName: device.name,
                pairingCode: normalizedCode
            )
        } else {
            connect(host: device.host, port: device.port, pairingCode: normalizedCode)
        }
    }

    func connect(host: String, port: Int, pairingCode: String) {
        disconnect(keepImage: true)
        decryptionKey = Self.pairingKey(for: pairingCode)

        guard let rawPort = UInt16(exactly: port), let nwPort = NWEndpoint.Port(rawValue: rawPort) else {
            status = "잘못된 포트: \(port)"
            return
        }
        receivedFrameCount = 0

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.noDelay = true
        let parameters = NWParameters(tls: nil, tcp: tcpOptions)

        let connection = NWConnection(host: NWEndpoint.Host(host), port: nwPort, using: parameters)
        self.connection = connection
        status = "\(host):\(port)에 연결 중…"

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            self.handleConnectionState(state, connection: connection, pairingCode: pairingCode)
        }
        connection.start(queue: queue)
    }

    func disconnect() {
        disconnect(keepImage: false)
    }

    private func disconnect(keepImage: Bool) {
        connection?.cancel()
        connection = nil
        decryptionKey = nil

        if let usbSocket {
            close(usbSocket)
            self.usbSocket = nil
        }

        if !keepImage {
            image = nil
            receivedFrameCount = 0
        }

        status = "연결 해제"
    }

    private func connectUSB(deviceID: Int, port: Int, displayName: String, pairingCode: String) {
        disconnect(keepImage: true)
        decryptionKey = Self.pairingKey(for: pairingCode)
        receivedFrameCount = 0
        transportLabel = "USB 직접 연결"
        status = "\(displayName) USB 연결 중…"

        usbQueue.async { [weak self] in
            guard let self else { return }

            do {
                let socket = try UsbMuxClient.connectToDevice(deviceID: deviceID, port: UInt16(port))
                self.usbSocket = socket
                let challenge = try self.readChallenge(from: socket)
                let authentication = self.authenticationMessage(
                    challenge: challenge,
                    pairingCode: pairingCode,
                    profile: "wired"
                )
                try UsbMuxClient.writeAll(authentication, to: socket)

                DispatchQueue.main.async {
                    self.status = "연결됨 (USB 직접 연결). 프레임 수신 중…"
                }

                self.receiveUSBFrames(from: socket)
            } catch {
                DispatchQueue.main.async {
                    self.status = "USB 연결 실패: \(error.localizedDescription)"
                }
            }
        }
    }

    private func handleConnectionState(
        _ state: NWConnection.State,
        connection: NWConnection,
        pairingCode: String
    ) {
        switch state {
        case .ready:
            let actualTransport = connection.currentPath.map(Self.transportLabel(for:)) ?? "네트워크"
            transportLabel = actualTransport == "유선 최적화" ? actualTransport : "\(actualTransport) · 고성능 요청"
            receiveChallenge(from: connection, pairingCode: pairingCode)
        case .waiting(let error):
            updateStatus("연결 대기 중: \(error.localizedDescription)")
        case .failed(let error):
            updateStatus("연결 실패: \(error.localizedDescription)")
            connection.cancel()
        case .cancelled:
            updateStatus("연결 종료")
        default:
            break
        }
    }

    private func receiveHeader(from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            if let error {
                self.updateStatus("헤더 수신 오류: \(error.localizedDescription)")
                return
            }

            guard !isComplete else {
                self.updateStatus("iPad가 연결을 종료했습니다")
                return
            }

            guard let data, data.count == 4 else {
                self.updateStatus("잘못된 프레임 헤더")
                connection.cancel()
                return
            }

            let length = self.decodeFrameLength(data)

            guard length > 0, length <= self.maxFrameSize else {
                self.updateStatus("잘못된 프레임 크기: \(length) bytes")
                connection.cancel()
                return
            }

            self.receiveFrame(length: length, from: connection)
        }
    }

    private func receiveFrame(length: Int, from connection: NWConnection) {
        connection.receive(minimumIncompleteLength: length, maximumLength: length) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }

            if let error {
                self.updateStatus("프레임 수신 오류: \(error.localizedDescription)")
                return
            }

            guard !isComplete else {
                self.updateStatus("iPad가 연결을 종료했습니다")
                return
            }

            guard let data, data.count == length else {
                self.updateStatus("프레임 크기 불일치")
                connection.cancel()
                return
            }

            if let decrypted = decryptFrame(data), let image = NSImage(data: decrypted) {
                DispatchQueue.main.async {
                    self.image = image
                    self.receivedFrameCount += 1
                    if self.receivedFrameCount % 15 == 0 {
                        self.status = "수신 중 · \(self.transportLabel) (\(length) bytes)"
                    }
                }
            } else {
                updateStatus("프레임 인증 또는 이미지 디코딩 실패")
                connection.cancel()
                return
            }

            receiveHeader(from: connection)
        }
    }

    private func receiveUSBFrames(from socket: Int32) {
        while usbSocket == socket {
            do {
                let header = try UsbMuxClient.readExact(from: socket, byteCount: 4)
                let length = decodeFrameLength(header)

                guard length > 0, length <= maxFrameSize else {
                    updateStatus("USB 프레임 크기 오류: \(length) bytes")
                    close(socket)
                    return
                }

                let data = try UsbMuxClient.readExact(from: socket, byteCount: length)
                guard displayFrame(data, length: length) else {
                    close(socket)
                    return
                }
            } catch {
                if usbSocket == socket {
                    updateStatus("USB 수신 종료: \(error.localizedDescription)")
                }
                close(socket)
                return
            }
        }
    }

    private func displayFrame(_ data: Data, length: Int) -> Bool {
        if let decrypted = decryptFrame(data), let image = NSImage(data: decrypted) {
            DispatchQueue.main.async {
                self.image = image
                self.receivedFrameCount += 1
                if self.receivedFrameCount % 15 == 0 {
                    self.status = "수신 중 · \(self.transportLabel) (\(length) bytes)"
                }
            }
            return true
        } else {
            updateStatus("USB 프레임 인증 또는 이미지 디코딩 실패")
            return false
        }
    }

    private func decodeFrameLength(_ data: Data) -> Int {
        data.reduce(0) { partial, byte in
            (partial << 8) | Int(byte)
        }
    }

    private func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.status = status
        }
    }

    private func receiveChallenge(
        from connection: NWConnection,
        pairingCode: String,
        buffer: Data = Data()
    ) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 128) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            guard error == nil, !isComplete, let data else {
                self.updateStatus("iPad 연결 인증 요청이 올바르지 않습니다")
                connection.cancel()
                return
            }

            var received = buffer
            received.append(data)
            guard received.count <= 128 else {
                self.updateStatus("iPad 연결 인증 요청이 너무 깁니다")
                connection.cancel()
                return
            }
            guard received.contains(0x0A) else {
                self.receiveChallenge(
                    from: connection,
                    pairingCode: pairingCode,
                    buffer: received
                )
                return
            }
            guard let challenge = self.parseChallenge(received) else {
                self.updateStatus("iPad 연결 인증 요청이 올바르지 않습니다")
                connection.cancel()
                return
            }

            let message = self.authenticationMessage(
                challenge: challenge,
                pairingCode: pairingCode,
                profile: "wired"
            )
            connection.send(content: message, completion: .contentProcessed { [weak self, weak connection] error in
                guard let self, let connection else { return }
                if let error {
                    self.updateStatus("연결 인증 전송 실패: \(error.localizedDescription)")
                    connection.cancel()
                    return
                }
                self.updateStatus("인증됨 (\(self.transportLabel)). 암호화된 프레임 수신 중…")
                self.receiveHeader(from: connection)
            })
        }
    }

    private func readChallenge(from socket: Int32) throws -> Data {
        var line = Data()
        while line.count < 128 {
            let byte = try UsbMuxClient.readExact(from: socket, byteCount: 1)
            if byte.first == 0x0A {
                guard let challenge = parseChallenge(line) else {
                    throw UsbMuxClient.UsbMuxError.invalidResponse
                }
                return challenge
            }
            line.append(byte)
        }
        throw UsbMuxClient.UsbMuxError.invalidResponse
    }

    private func parseChallenge(_ data: Data) -> Data? {
        let line = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard line.hasPrefix("CHALLENGE "),
              let challenge = Data(base64Encoded: String(line.dropFirst(10))),
              challenge.count == 32 else {
            return nil
        }
        return challenge
    }

    private func authenticationMessage(
        challenge: Data,
        pairingCode: String,
        profile: String
    ) -> Data {
        let key = Self.pairingKey(for: pairingCode)
        let authentication = Data(HMAC<SHA256>.authenticationCode(for: challenge, using: key))
        return Data("AUTH \(authentication.base64EncodedString())\nPROFILE \(profile)\n".utf8)
    }

    private func decryptFrame(_ data: Data) -> Data? {
        guard let decryptionKey,
              let box = try? ChaChaPoly.SealedBox(combined: data) else {
            return nil
        }
        return try? ChaChaPoly.open(box, using: decryptionKey)
    }

    private static func pairingKey(for pairingCode: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(pairingCode.utf8)))
    }

    private static func normalizedPairingCode(_ code: String) -> String {
        code.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
    }

    private static func transportLabel(for path: NWPath) -> String {
        if path.usesInterfaceType(.wiredEthernet) || path.usesInterfaceType(.loopback) || path.usesInterfaceType(.other) {
            return "유선 최적화"
        }
        if path.usesInterfaceType(.wifi) {
            return "Wi‑Fi"
        }
        return "네트워크"
    }
}
