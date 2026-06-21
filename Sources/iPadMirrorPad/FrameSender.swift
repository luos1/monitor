import Combine
import Network
import UIKit

final class FrameSender: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var status = "서버 대기 중"

    let port: UInt16 = 12_345

    private final class Session {
        let connection: NWConnection
        var isSending = false
        var timer: DispatchSourceTimer?

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    private let queue = DispatchQueue(label: "dev.local.iPadMirrorPad.FrameSender", qos: .userInitiated)
    private let frameInterval: DispatchTimeInterval = .milliseconds(100)
    private let jpegQuality: CGFloat = 0.6

    private var listener: NWListener?
    private var sessions: [ObjectIdentifier: Session] = [:]

    func startServer() {
        guard listener == nil else { return }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            status = "잘못된 포트: \(port)"
            return
        }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters, on: nwPort)
            listener.stateUpdateHandler = { [weak self] state in
                self?.handleListenerState(state)
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }

            self.listener = listener
            listener.start(queue: queue)

            DispatchQueue.main.async {
                self.isRunning = true
                self.status = "Mac 연결 대기 중…"
            }
        } catch {
            status = "서버 시작 실패: \(error.localizedDescription)"
        }
    }

    func stopServer() {
        listener?.cancel()
        listener = nil

        for session in sessions.values {
            session.timer?.cancel()
            session.connection.cancel()
        }
        sessions.removeAll()

        DispatchQueue.main.async {
            self.isRunning = false
            self.status = "서버 중지"
        }
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            updateStatus("Mac 연결 대기 중 (포트 \(port))")
        case .failed(let error):
            updateStatus("서버 오류: \(error.localizedDescription)")
            stopServer()
        case .cancelled:
            updateStatus("서버 중지")
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        let session = Session(connection: connection)
        sessions[id] = session

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }
            self.handleConnectionState(state, id: id, connection: connection)
        }
        connection.start(queue: queue)
    }

    private func handleConnectionState(_ state: NWConnection.State, id: ObjectIdentifier, connection: NWConnection) {
        switch state {
        case .ready:
            updateStatus("Mac 연결됨. 화면 전송 중…")
            startSendingFrames(id: id)
        case .failed(let error):
            updateStatus("Mac 연결 실패: \(error.localizedDescription)")
            removeSession(id: id)
        case .cancelled:
            removeSession(id: id)
        default:
            break
        }
    }

    private func startSendingFrames(id: ObjectIdentifier) {
        guard let session = sessions[id], session.timer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: frameInterval)
        timer.setEventHandler { [weak self, weak session] in
            guard let self, let session, !session.isSending else { return }
            session.isSending = true

            DispatchQueue.main.async { [weak self, weak session] in
                guard let self, let session else { return }
                let frameData = Self.captureScreen()?.jpegData(compressionQuality: self.jpegQuality)

                self.queue.async { [weak self, weak session] in
                    guard let self, let session else { return }
                    guard let current = self.sessions[id], current === session else { return }

                    guard let frameData else {
                        session.isSending = false
                        self.updateStatus("화면 캡처 실패")
                        return
                    }

                    self.send(frameData, session: session, id: id)
                }
            }
        }

        session.timer = timer
        timer.resume()
    }

    private func send(_ frameData: Data, session: Session, id: ObjectIdentifier) {
        guard frameData.count <= UInt32.max else {
            session.isSending = false
            updateStatus("프레임이 너무 큽니다")
            return
        }

        var length = UInt32(frameData.count).bigEndian
        var payload = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        payload.append(frameData)

        session.connection.send(content: payload, completion: .contentProcessed { [weak self, weak session] error in
            guard let self, let session else { return }

            self.queue.async {
                session.isSending = false

                if let error {
                    self.updateStatus("프레임 전송 실패: \(error.localizedDescription)")
                    self.removeSession(id: id)
                }
            }
        })
    }

    private func removeSession(id: ObjectIdentifier) {
        guard let session = sessions.removeValue(forKey: id) else { return }
        session.timer?.cancel()
        session.connection.cancel()

        if sessions.isEmpty {
            updateStatus("Mac 연결 대기 중 (포트 \(port))")
        }
    }

    private static func captureScreen() -> UIImage? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windowScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard let window = windowScene?.windows.first(where: { $0.isKeyWindow }) ?? windowScene?.windows.first else {
            return nil
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = window.screen.scale

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds, format: format)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
    }

    private func updateStatus(_ status: String) {
        DispatchQueue.main.async {
            self.status = status
        }
    }
}
