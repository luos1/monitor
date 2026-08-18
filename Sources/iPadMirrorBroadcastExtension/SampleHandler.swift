import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ImageIO
import ReplayKit

private final class BroadcastUsageGate {
    private let defaults: UserDefaults
    private let usedSecondsKey = "monitor.pad.usage.usedSeconds"
    private let bonusSecondsKey = "monitor.pad.usage.bonusSeconds"
    private let freeLimitSeconds = 60 * 60
    private let maximumBonusSeconds = 24 * 60 * 60
    private var storedUsedSeconds: Int
    private var accumulatedSessionSeconds = 0
    private var activeStartedAt: TimeInterval?
    private var lastPersistedTotal: Int

    init?() {
        guard let defaults = BroadcastSharedSettings.defaults else { return nil }
        self.defaults = defaults
        self.storedUsedSeconds = max(0, defaults.integer(forKey: usedSecondsKey))
        self.lastPersistedTotal = storedUsedSeconds
        self.activeStartedAt = ProcessInfo.processInfo.systemUptime
    }

    func pause() {
        accumulateActiveTime()
        persist()
    }

    func resume() {
        guard activeStartedAt == nil else { return }
        activeStartedAt = ProcessInfo.processInfo.systemUptime
    }

    func canContinue() -> Bool {
        persist()
        if BroadcastSharedSettings.hasRecentVerifiedLifetimeEntitlement() {
            return true
        }
        let bonusSeconds = min(
            maximumBonusSeconds,
            max(0, defaults.integer(forKey: bonusSecondsKey))
        )
        return currentUsedSeconds < freeLimitSeconds + bonusSeconds
    }

    func finish() {
        accumulateActiveTime()
        persist(force: true)
    }

    private var currentUsedSeconds: Int {
        let activeSeconds = activeStartedAt.map {
            max(0, Int(ProcessInfo.processInfo.systemUptime - $0))
        } ?? 0
        return storedUsedSeconds + accumulatedSessionSeconds + activeSeconds
    }

    private func accumulateActiveTime() {
        guard let activeStartedAt else { return }
        accumulatedSessionSeconds += max(
            0,
            Int(ProcessInfo.processInfo.systemUptime - activeStartedAt)
        )
        self.activeStartedAt = nil
    }

    private func persist(force: Bool = false) {
        let total = currentUsedSeconds
        guard force || total > lastPersistedTotal else { return }
        defaults.set(total, forKey: usedSecondsKey)
        lastPersistedTotal = total
    }
}

final class SampleHandler: RPBroadcastSampleHandler {
    private let frameServer = BroadcastFrameServer()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let stopLock = NSLock()
    private var lastEncodedFrameTime = CMTime.zero
    private var stopRequested = false
    private var lastStopRequestToken: String?
    private var usageGate: BroadcastUsageGate?

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        setStopRequested(false)
        lastStopRequestToken = BroadcastSharedSettings.currentStopRequestToken()
        usageGate = BroadcastUsageGate()
        addStopObserver()
        guard usageGate?.canContinue() == true else {
            finishBroadcastWithError(Self.usageLimitReachedError)
            return
        }
        frameServer.start()
    }

    override func broadcastPaused() {
        usageGate?.pause()
    }

    override func broadcastResumed() {
        usageGate?.resume()
    }

    override func broadcastFinished() {
        usageGate?.finish()
        usageGate = nil
        removeStopObserver()
        frameServer.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        guard usageGate?.canContinue() == true else {
            finishBroadcastWithError(Self.usageLimitReachedError)
            return
        }
        guard frameServer.canAcceptFrame else { return }
        if shouldStopBroadcast() {
            finishBroadcastWithError(Self.userStoppedBroadcastError)
            return
        }

        let profile = frameServer.captureProfile
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if lastEncodedFrameTime != .zero {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(presentationTime, lastEncodedFrameTime))
            guard elapsed >= profile.minimumFrameInterval else { return }
        }
        lastEncodedFrameTime = presentationTime

        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
            let scaledImage = scaledCIImage(ciImage, maxEncodedDimension: profile.maxEncodedDimension)
            let renderRect = scaledImage.extent.integral

            guard let cgImage = ciContext.createCGImage(scaledImage, from: renderRect) else { return }
            guard let jpegData = Self.encodeJPEG(cgImage, quality: profile.jpegQuality) else { return }

            frameServer.broadcastJPEGFrame(jpegData)
        }
    }

    private static func encodeJPEG(_ image: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }

        let options: CFDictionary = [
            kCGImageDestinationLossyCompressionQuality: quality
        ] as CFDictionary
        CGImageDestinationAddImage(destination, image, options)

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        return data as Data
    }

    private func shouldStopBroadcast() -> Bool {
        stopLock.lock()
        defer { stopLock.unlock() }
        return stopRequested
    }

    private func setStopRequested(_ requested: Bool) {
        stopLock.lock()
        stopRequested = requested
        stopLock.unlock()
    }

    private func scaledCIImage(_ image: CIImage, maxEncodedDimension: CGFloat) -> CIImage {
        let extent = image.extent
        let longestSide = max(extent.width, extent.height)
        guard longestSide > maxEncodedDimension else { return image }

        let scale = maxEncodedDimension / longestSide
        return image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
    }

    private func addStopObserver() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            Self.stopNotificationCallback,
            Self.stopNotificationName.rawValue,
            nil,
            .deliverImmediately
        )
    }

    private func removeStopObserver() {
        CFNotificationCenterRemoveObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque(),
            Self.stopNotificationName,
            nil
        )
    }

    private static let stopNotificationName = CFNotificationName("dev.local.iPadMirrorPad.stopBroadcast" as CFString)

    private static let stopNotificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
        guard let observer else { return }
        let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
        let token = BroadcastSharedSettings.currentStopRequestToken()
        guard token != nil, token != handler.lastStopRequestToken else { return }
        handler.lastStopRequestToken = token
        handler.setStopRequested(true)
    }
    private static let userStoppedBroadcastError = NSError(
        domain: "dev.local.iPadMirrorPad.broadcast",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "사용자가 iPad 앱에서 화면 공유를 종료했습니다."]
    )
    private static let usageLimitReachedError = NSError(
        domain: "dev.local.iPadMirrorPad.usage",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "무료 사용 시간이 끝났습니다. iPad 앱에서 시간을 연장하거나 영구 사용을 구매하세요."]
    )
}
