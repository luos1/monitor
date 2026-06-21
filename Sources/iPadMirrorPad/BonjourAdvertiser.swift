import Combine
import Foundation
import UIKit

final class BonjourAdvertiser: NSObject, ObservableObject {
    @Published private(set) var status = "Bonjour 광고 대기 중"

    private var service: NetService?
    private let serviceType = "_ipadmirror._tcp."

    func startAdvertising(port: UInt16) {
        guard service == nil else { return }

        let service = NetService(
            domain: "local.",
            type: serviceType,
            name: UIDevice.current.name,
            port: Int32(port)
        )
        service.delegate = self
        service.includesPeerToPeer = true
        service.publish()

        self.service = service
        status = "Bonjour 광고 시작 중…"
    }

    func stopAdvertising() {
        service?.stop()
        service = nil
        status = "Bonjour 광고 중지"
    }
}

extension BonjourAdvertiser: NetServiceDelegate {
    func netServiceDidPublish(_ sender: NetService) {
        DispatchQueue.main.async {
            self.status = "Mac에서 검색 가능: \(sender.name)"
        }
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        DispatchQueue.main.async {
            self.status = "Bonjour 광고 실패: \(errorDict)"
        }
    }

    func netServiceDidStop(_ sender: NetService) {
        DispatchQueue.main.async {
            self.status = "Bonjour 광고 중지"
        }
    }
}
