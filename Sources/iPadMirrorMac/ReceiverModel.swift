import Combine
import Foundation
import Network

final class ReceiverModel: NSObject, ObservableObject {
    struct Client: Identifiable, Equatable {
        let id = UUID()
        let endpoint: String
        var lastMessage: String
    }

    @Published private(set) var isRunning = false
    @Published private(set) var serviceName = Host.current().localizedName ?? "Mac"
    @Published private(set) var port: UInt16 = 0
    @Published private(set) var status = "Stopped"
    @Published private(set) var clients: [Client] = []
    @Published private(set) var events: [String] = []

    private var listener: NWListener?
    private var service: NetService?
    private let serviceType = "_ipadmirror._tcp."
    private let serviceDomain = "local."

    func start() {
        guard !isRunning else { return }

        do {
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            let listener = try NWListener(using: parameters, on: .any)
            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    self?.handleListenerState(state)
                }
            }
            listener.newConnectionHandler = { [weak self] connection in
                self?.accept(connection)
            }

            self.listener = listener
            listener.start(queue: .global(qos: .userInitiated))
            isRunning = true
            status = "Starting receiver…"
            appendEvent("Starting TCP receiver")
        } catch {
            status = "Failed to start: \(error.localizedDescription)"
            appendEvent(status)
        }
    }

    func stop() {
        service?.stop()
        service = nil
        listener?.cancel()
        listener = nil
        clients.removeAll()
        port = 0
        isRunning = false
        status = "Stopped"
        appendEvent("Stopped receiver")
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            guard let listener else { return }
            let resolvedPort = listener.port?.rawValue ?? 0
            port = resolvedPort
            publishBonjourService(port: resolvedPort)
            status = "Waiting for iPad on port \(resolvedPort)"
            appendEvent("Receiver ready on port \(resolvedPort)")
        case .failed(let error):
            status = "Listener failed: \(error.localizedDescription)"
            appendEvent(status)
            stop()
        case .cancelled:
            status = "Stopped"
        default:
            break
        }
    }

    private func publishBonjourService(port: UInt16) {
        service?.stop()

        let service = NetService(
            domain: serviceDomain,
            type: serviceType,
            name: serviceName,
            port: Int32(port)
        )
        service.delegate = self
        service.includesPeerToPeer = true
        service.publish()

        self.service = service
        appendEvent("Advertising Bonjour service \(serviceType) as \(serviceName)")
    }

    private func accept(_ connection: NWConnection) {
        let endpoint = String(describing: connection.endpoint)

        connection.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                switch state {
                case .ready:
                    self?.clients.append(Client(endpoint: endpoint, lastMessage: "Connected"))
                    self?.appendEvent("Client connected: \(endpoint)")
                    self?.receive(from: connection, endpoint: endpoint)
                case .failed(let error):
                    self?.appendEvent("Client failed \(endpoint): \(error.localizedDescription)")
                    self?.removeClient(endpoint: endpoint)
                case .cancelled:
                    self?.appendEvent("Client disconnected: \(endpoint)")
                    self?.removeClient(endpoint: endpoint)
                default:
                    break
                }
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func receive(from connection: NWConnection, endpoint: String) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 64 * 1024) { [weak self] data, _, isComplete, error in
            DispatchQueue.main.async {
                if let data, !data.isEmpty {
                    let text = String(decoding: data, as: UTF8.self)
                    self?.updateClient(endpoint: endpoint, message: text.trimmingCharacters(in: .whitespacesAndNewlines))
                    self?.appendEvent("Received \(data.count) bytes from \(endpoint)")
                }

                if let error {
                    self?.appendEvent("Receive error from \(endpoint): \(error.localizedDescription)")
                    connection.cancel()
                    return
                }

                if isComplete {
                    connection.cancel()
                    return
                }

                self?.receive(from: connection, endpoint: endpoint)
            }
        }
    }

    private func updateClient(endpoint: String, message: String) {
        guard let index = clients.firstIndex(where: { $0.endpoint == endpoint }) else { return }
        clients[index].lastMessage = message.isEmpty ? "Received data" : message
    }

    private func removeClient(endpoint: String) {
        clients.removeAll { $0.endpoint == endpoint }
    }

    private func appendEvent(_ event: String) {
        let timestamp = Self.timestampFormatter.string(from: Date())
        events.insert("[\(timestamp)] \(event)", at: 0)
        if events.count > 200 {
            events.removeLast(events.count - 200)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

extension ReceiverModel: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        appendEvent("Bonjour published: \(sender.name).\(sender.type)\(sender.domain)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String : NSNumber]) {
        status = "Bonjour publish failed"
        appendEvent("Bonjour publish failed: \(errorDict)")
    }

    func netServiceDidStop(_ sender: NetService) {
        appendEvent("Bonjour stopped")
    }
}
