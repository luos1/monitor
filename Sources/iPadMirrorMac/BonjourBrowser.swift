import iPadMirrorShared
import Combine
import Foundation

final class BonjourBrowser: NSObject, ObservableObject {
    struct Device: Identifiable, Hashable {
        enum Transport: Hashable {
            case network
            #if !IPADMIRROR_MAC_APP_STORE
            case usb(deviceID: Int, serialNumber: String)
            #endif
        }

        let id: String
        let name: String
        let host: String
        let port: Int
        let transport: Transport

        var endpointDescription: String {
            switch transport {
            case .network:
                return MacDistribution.isNetworkOnly ? MacStoreCopy.encryptedConnection : MirrorL10n.text("Wi‑Fi · 암호화 연결")
            #if !IPADMIRROR_MAC_APP_STORE
            case .usb:
                return MirrorL10n.text("USB 직접 연결")
            #endif
            }
        }

    #if !IPADMIRROR_MAC_APP_STORE
        var usbDeviceID: Int? {
            if case .usb(let deviceID, _) = transport {
                return deviceID
            }
            return nil
        }

    #endif

        init(name: String, host: String, port: Int) {
            self.name = name
            self.host = host
            self.port = port
            self.transport = .network
            self.id = "network-\(name)-\(host)-\(port)"
        }

    #if !IPADMIRROR_MAC_APP_STORE
        init(usb device: UsbMuxClient.Device, port: Int) {
            self.name = device.name
            self.host = "USB"
            self.port = port
            self.transport = .usb(deviceID: device.deviceID, serialNumber: device.serialNumber)
            self.id = "usb-\(device.deviceID)-\(device.serialNumber)-\(port)"
        }
    #endif

    }

    @Published private(set) var devices: [Device] = []
    @Published private(set) var status = MirrorL10n.text("iPad 화면 방송 검색 대기 중")

    private var browser: NetServiceBrowser?
    private var foundServices: [NetService] = []
    private let serviceType = "_ipadmirror._tcp."
    #if !IPADMIRROR_MAC_APP_STORE
    private let mirrorPort = 12_346
    #endif

    private var searchingStatus: String { MacDistribution.isNetworkOnly ? MacStoreCopy.searching : MirrorL10n.text("USB와 네트워크에서 iPad 화면 방송 검색 중…") }

    func startSearching() {
        guard browser == nil else {
            #if !IPADMIRROR_MAC_APP_STORE
            refreshUSBDevices()
            #endif
            return
        }

        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.includesPeerToPeer = false
        browser.searchForServices(ofType: serviceType, inDomain: "local.")

        self.browser = browser
        status = searchingStatus
        #if !IPADMIRROR_MAC_APP_STORE
        refreshUSBDevices()
        #endif
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

        status = MirrorL10n.text("iPad 화면 방송 검색 중지")
    }

    #if !IPADMIRROR_MAC_APP_STORE
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
                self.status = self.devices.isEmpty ? self.searchingStatus : MirrorL10n.format("{0}개 화면 방송 발견", String(describing: self.devices.count))
            }
        }
    }

    #endif

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
            #if !IPADMIRROR_MAC_APP_STORE
            switch (lhs.transport, rhs.transport) {
            case (.usb, .network):
                return true
            case (.network, .usb):
                return false
            default:
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            #else
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            #endif
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
            self.status = MirrorL10n.format("iPad 화면 방송 확인 중: {0}", String(describing: service.name))
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
            self.status = self.devices.isEmpty ? self.searchingStatus : MirrorL10n.format("{0}개 화면 방송 발견", String(describing: self.devices.count))
        }
    }

    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.status = MirrorL10n.format("Bonjour 검색 실패: {0}", String(describing: errorDict))
        }
    }
}

extension BonjourBrowser: NetServiceDelegate {
    func netServiceDidResolveAddress(_ service: NetService) {
        guard let host = service.hostName, service.port > 0 else { return }
        let device = Device(name: service.name, host: host, port: service.port)

        DispatchQueue.main.async {
            self.upsert(device)
            self.status = MirrorL10n.format("{0}개 화면 방송 발견", String(describing: self.devices.count))
        }
    }

    func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.status = MirrorL10n.format("iPad 주소 확인 실패: {0}", String(describing: sender.name))
        }
    }
}
