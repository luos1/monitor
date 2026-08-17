import Combine
import iPadMirrorShared

@MainActor
final class MacAdRewardController: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var isPresenting = false
    @Published var status = "광고 연장은 iPad 앱의 AdMob 리워드 광고로 사용할 수 있습니다."
    let isSupported = false

    func start() {}

    func showRewarded() async throws {
        throw AdRewardError.unsupported
    }
}
