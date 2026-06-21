import CoreGraphics
import Foundation
import ImageIO
import Network
import UIKit

struct BroadcastCaptureProfile {
    let name: String
    let targetFPS: Double
    let maxEncodedDimension: CGFloat
    let jpegQuality: CGFloat
    let queueFramesWhenBusy: Bool
    let maxQueuedFrames: Int

    var minimumFrameInterval: TimeInterval {
        1.0 / targetFPS
    }

    static let wired = BroadcastCaptureProfile(
        name: "유선",
        targetFPS: 30,
        maxEncodedDimension: 1920,
        jpegQuality: 0.52,
        queueFramesWhenBusy: true,
        maxQueuedFrames: 90
    )

    static let wireless = BroadcastCaptureProfile(
        name: "무선",
        targetFPS: 12,
        maxEncodedDimension: 1280,
        jpegQuality: 0.38,
        queueFramesWhenBusy: false,
        maxQueuedFrames: 1
    )
}

final class BroadcastFrameServer: NSObject {
    private final class Session {
        let connection: NWConnection
        var profile = BroadcastCaptureProfile.wireless
        var isSending = false
        var queuedFrames: [Data] = []

        init(connection: NWConnection) {
            self.connection = connection
        }
    }

    private let queue = DispatchQueue(label: "dev.local.iPadMirrorPad.BroadcastFrameServer", qos: .userInitiated)
    private let clientCountLock = NSLock()
    private let port: UInt16 = 12_346
    private let serviceType = "_ipadmirror._tcp."

    private var listener: NWListener?
    private var service: NetService?
    private var sessions: [ObjectIdentifier: Session] = [:]
    private var activeClientCount = 0
    private var lastFrameTime: Date = .distantPast

    var hasClients: Bool {
        clientCountLock.lock()
        defer { clientCountLock.unlock() }
        return activeClientCount > 0
    }

    var captureProfile: BroadcastCaptureProfile {
        queue.sync {
            guard !sessions.isEmpty else { return .wireless }
            return sessions.values.contains { $0.profile.name == BroadcastCaptureProfile.wired.name } ? .wired : .wireless
        }
    }

    var canAcceptFrame: Bool {
        queue.sync {
            guard !sessions.isEmpty else { return false }
            if sessions.values.contains(where: { $0.profile.queueFramesWhenBusy }) {
                return true
            }
            return sessions.values.contains { !$0.isSending }
        }
    }

    func start() {
        guard listener == nil else { return }

        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        do {
            let tcpOptions = NWProtocolTCP.Options()
            tcpOptions.noDelay = true

            let parameters = NWParameters(tls: nil, tcp: tcpOptions)
            parameters.allowLocalEndpointReuse = true
            parameters.includePeerToPeer = true

            let listener = try NWListener(using: parameters, on: nwPort)
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    self?.stop()
                }
            }

            self.listener = listener
            listener.start(queue: queue)
            publishService(port: port)
        } catch {
            stop()
        }
    }

    func stop() {
        service?.stop()
        service = nil

        listener?.cancel()
        listener = nil

        for session in sessions.values {
            session.connection.cancel()
        }
        sessions.removeAll()
        setActiveClientCount(0)
    }

    func broadcastJPEGFrame(_ frame: Data, capturedAt: Date = Date()) {
        queue.async { [weak self] in
            guard let self else { return }
            guard !self.sessions.isEmpty else { return }

            let profile = self.currentCaptureProfileOnQueue()
            guard capturedAt.timeIntervalSince(self.lastFrameTime) >= profile.minimumFrameInterval else { return }
            self.lastFrameTime = capturedAt

            for (id, session) in self.sessions {
                if session.isSending {
                    if session.profile.queueFramesWhenBusy {
                        self.enqueue(frame, for: session)
                    }
                } else {
                    self.send(frame, session: session, id: id)
                }
            }
        }
    }

    private func publishService(port: UInt16) {
        service?.stop()

        let name = UIDevice.current.name
        let service = NetService(domain: "local.", type: serviceType, name: name, port: Int32(port))
        service.includesPeerToPeer = true
        service.publish()

        self.service = service
    }

    private func accept(_ connection: NWConnection) {
        let id = ObjectIdentifier(connection)
        let session = Session(connection: connection)
        sessions[id] = session

        connection.stateUpdateHandler = { [weak self, weak connection] state in
            guard let self, let connection else { return }

            switch state {
            case .ready:
                self.queue.async {
                    if let session = self.sessions[id] {
                        session.profile = connection.currentPath.map(Self.profile(for:)) ?? .wireless
                        self.receiveControlMessages(for: session, id: id)
                    }
                    self.setActiveClientCount(self.sessions.count)
                }
            case .failed, .cancelled:
                self.queue.async {
                    self.sessions.removeValue(forKey: id)
                    self.setActiveClientCount(self.sessions.count)
                    connection.cancel()
                }
            default:
                break
            }
        }
        connection.start(queue: queue)
    }

    private func receiveControlMessages(for session: Session, id: ObjectIdentifier) {
        session.connection.receive(minimumIncompleteLength: 1, maximumLength: 128) { [weak self, weak session] data, _, isComplete, error in
            guard let self, let session else { return }

            self.queue.async {
                guard self.sessions[id] === session else { return }

                if let data, !data.isEmpty {
                    self.applyControlMessage(data, to: session)
                }

                if error != nil || isComplete {
                    return
                }

                self.receiveControlMessages(for: session, id: id)
            }
        }
    }

    private func applyControlMessage(_ data: Data, to session: Session) {
        let message = String(decoding: data, as: UTF8.self).lowercased()

        if message.contains("profile wired") {
            session.profile = .wired
        } else if message.contains("profile wireless") {
            session.profile = .wireless
        }
    }

    private func enqueue(_ frame: Data, for session: Session) {
        if session.queuedFrames.count >= session.profile.maxQueuedFrames {
            session.queuedFrames.removeFirst()
        }
        session.queuedFrames.append(frame)
    }

    private func send(_ frame: Data, session: Session, id: ObjectIdentifier) {
        guard frame.count <= UInt32.max else { return }

        session.isSending = true

        var length = UInt32(frame.count).bigEndian
        var payload = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
        payload.append(frame)

        session.connection.send(content: payload, completion: .contentProcessed { [weak self, weak session] error in
            guard let self, let session else { return }

            self.queue.async {
                if error != nil {
                    session.isSending = false
                    session.queuedFrames.removeAll()
                    session.connection.cancel()
                    self.sessions.removeValue(forKey: id)
                    self.setActiveClientCount(self.sessions.count)
                    return
                }

                if !session.queuedFrames.isEmpty {
                    let nextFrame = session.queuedFrames.removeFirst()
                    self.send(nextFrame, session: session, id: id)
                } else {
                    session.isSending = false
                }
            }
        })
    }

    private func currentCaptureProfileOnQueue() -> BroadcastCaptureProfile {
        guard !sessions.isEmpty else { return .wireless }
        return sessions.values.contains { $0.profile.name == BroadcastCaptureProfile.wired.name } ? .wired : .wireless
    }

    private static func profile(for path: NWPath) -> BroadcastCaptureProfile {
        if path.usesInterfaceType(.wiredEthernet) || path.usesInterfaceType(.loopback) || path.usesInterfaceType(.other) {
            return .wired
        }
        return .wireless
    }

    private func setActiveClientCount(_ count: Int) {
        clientCountLock.lock()
        activeClientCount = count
        clientCountLock.unlock()
    }
}
