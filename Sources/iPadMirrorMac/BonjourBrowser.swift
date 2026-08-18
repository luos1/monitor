import Combine
import Foundation

final class BonjourBrowser: NSObject, ObservableObject {
    struct Device: Identifiable, Hashable {
        enum Transport: Hashable {
            case network
            case usb(deviceID: Int, serialNumber: String)
        }

        let id: String
        let name: String
        let host: String
        let port: Int
        let transport: Transport

        var endpointDescription: String {
            switch transport {
            case .network:
                return "Wi‑Fi · 암호화 연결"
            case .usb:
                return "USB 직접 연결"
            }
        }

        var usbDeviceID: Int? {
            if case .usb(let deviceID, _) = transport {
                return deviceID
            }
            return nil
        }

        init(name: String, host: String, port: Int) {
            self.name = name
            self.host = host
            self.port = port
            self.transport = .network
            self.id = "network-\(name)-\(host)-\(port)"
        }

        init(usb device: UsbMuxClient.Device, port: Int) {
            self.name = device.name
            self.host = "USB"
            self.port = port
            self.transport = .usb(deviceID: device.deviceID, serialNumber: device.serialNumber)
            self.id = "usb-\(device.deviceID)-\(device.serialNumber)-\(port)"
        }
    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var status = "iPad 화면 방송 검색 대기 중"

    private var browser: NetServiceBrowser?
    private var foundServices: [NetService] = []
    private let serviceType = "_ipadmirror._tcp."
    private let mirrorPort = 12_346

    func startSearching() {
        guard browser == nil else {
            refreshUSBDevices()
            return
        }

        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.includesPeerToPeer = false
        browser.searchForServices(ofType: serviceType, inDomain: "local.")

        self.browser = browser
        status = "USB와 네트워크에서 iPad 화면 방송 검색 중…"
        refreshUSBDevices()
    }

    func restartSearching() {
        stopSearching(clearDevices: true)
        startSearching()
    }

    func stopSearching(clearDevices: Bool = false) {
        browser?.stop()
        browser = nil
        foundServices.removeAll()

        if clearDevices {
            devices.removeAll()
        }

        status = "iPad 화면 방송 검색 중지"
    }

    private func refreshUSBDevices() {
        DispatchQueue.global(qos: .userInitiated).async {
            let usbDevices = (try? UsbMuxClient.listDevices()) ?? []
            let mirrorDevices = usbDevices.map { Device(usb: $0, port: self.mirrorPort) }

            DispatchQueue.main.async {
                self.devices.removeAll { device in
                    if case .usb = device.transport { return true }
                    return false
                }
                self.devices.append(contentsOf: mirrorDevices)
                self.sortDevices()
                self.status = self.devices.isEmpty ? "USB와 네트워크에서 iPad 화면 방송 검색 중…" : "\(self.devices.count)개 화면 방송 발견"
            }
        }
    }

    private func upsert(_ device: Device) {
        if let index = devices.firstIndex(where: { $0.id == device.id }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
        sortDevices()
    }

    private func sortDevices() {
        devices.sort { lhs, rhs in
            switch (lhs.transport, rhs.transport) {
            case (.usb, .network):
                return true
            case (.network, .usb):
                return false
            default:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
        }
    }
}

extension BonjourBrowser: NetServiceBrowserDelegate {
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        service.delegate = self
        service.includesPeerToPeer = false
        foundServices.append(service)
        service.resolve(withTimeout: 5)

        DispatchQueue.main.async {
            self.status = "iPad 화면 방송 확인 중: \(service.name)"
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        DispatchQueue.main.async {
            self.devices.removeAll { device in
                if case .network = device.transport {
                    return device.name == service.name
                }
                return false
            }
            self.status = self.devices.isEmpty ? "USB와 네트워크에서 iPad 화면 방송 검색 중…" : "\(self.devices.count)개 화면 방송 발견"
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.status = "Bonjour 검색 실패: \(errorDict)"
        }
    }
}

extension BonjourBrowser: NetServiceDelegate {
    func netServiceDidResolveAddress(_ service: NetService) {
        guard let host = service.hostName, service.port > 0 else { return }
        let device = Device(name: service.name, host: host, port: service.port)

        DispatchQueue.main.async {
            self.upsert(device)
            self.status = "\(self.devices.count)개 화면 방송 발견"
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.status = "iPad 주소 확인 실패: \(sender.name)"
        }
    }
}
