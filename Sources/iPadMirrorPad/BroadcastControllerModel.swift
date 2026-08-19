import Combine
import ReplayKit
import UIKit

final class BroadcastControllerModel: NSObject, ObservableObject {
    @Published private(set) var isBroadcasting = false
    @Published private(set) var status = "화면 공유 대기 중"

    private var broadcastController: RPBroadcastController?

    func startBroadcast(preferredExtension: String) {
        status = "방송 선택창 여는 중…"

        RPBroadcastActivityViewController.load(withPreferredExtension: preferredExtension) { [weak self] activityViewController, error in
            DispatchQueue.main.async {
                guard let self else { return }

                if let error {
                    self.status = "방송 선택창 오류: \(error.localizedDescription)"
                    return
                }

                guard let activityViewController else {
                    self.status = "방송 선택창을 열 수 없습니다"
                    return
                }

                activityViewController.delegate = self
                activityViewController.modalPresentationStyle = .formSheet

                guard let presenter = Self.topViewController() else {
                    self.status = "방송 선택창을 표시할 화면을 찾지 못했습니다"
                    return
                }

                presenter.present(activityViewController, animated: true)
            }
        }
    }

    func stopBroadcast() {
        BroadcastSharedSettings.requestStop()
        Self.postStopBroadcastNotification()

        guard let broadcastController else {
            status = "화면 공유 종료 요청 전송됨"
            isBroadcasting = false
            return
        }

        status = "화면 공유 종료 중…"
        broadcastController.finishBroadcast { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.status = "화면 공유 종료 오류: \(error.localizedDescription)"
                } else {
                    self?.status = "화면 공유 종료됨"
                    self?.isBroadcasting = false
                    self?.broadcastController = nil
                }
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let windowScene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var top = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? windowScene?.windows.first?.rootViewController else {
            return nil
        }

        while let presented = top.presentedViewController {
            top = presented
        }

        return top
    }

    private static func postStopBroadcastNotification() {
        let notificationName = CFNotificationName("com.raccoonmerchant.ipadmirror.stopBroadcast" as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            notificationName,
            nil,
            nil,
            true
        )
    }
}

extension BroadcastControllerModel: RPBroadcastActivityViewControllerDelegate {
    func broadcastActivityViewController(
        _ broadcastActivityViewController: RPBroadcastActivityViewController,
        didFinishWith broadcastController: RPBroadcastController?,
        error: Error?
    ) {
        broadcastActivityViewController.dismiss(animated: true)

        if let error {
            status = "방송 시작 오류: \(error.localizedDescription)"
            return
        }

        guard let broadcastController else {
            status = "방송 컨트롤러를 만들 수 없습니다"
            return
        }

        self.broadcastController = broadcastController
        status = "화면 공유 시작 중…"

        broadcastController.startBroadcast { [weak self] error in
            DispatchQueue.main.async {
                if let error {
                    self?.status = "화면 공유 시작 오류: \(error.localizedDescription)"
                    self?.isBroadcasting = false
                    return
                }

                self?.isBroadcasting = true
                self?.status = "화면 공유 중"
            }
        }
    }
}
