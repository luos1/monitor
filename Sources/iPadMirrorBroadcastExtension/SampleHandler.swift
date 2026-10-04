import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ImageIO
import ReplayKit

/// Shares ReplayKit state with the containing app, including broadcasts
/// started from the system picker rather than RPBroadcastController.
private final class BroadcastActivityReporter {
    private let lock = NSLock()
    private var activity = BroadcastSharedSettings.Activity.idle
    private var timer: DispatchSourceTimer?

    init() {
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "iPadMirror.BroadcastHeartbeat"))
        self.timer = timer
        timer.schedule(deadline: .now(), repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.lock.lock()
            defer { self.lock.unlock() }
            guard self.activity != .idle else { return }
            BroadcastSharedSettings.writeActivity(self.activity)
        }
        timer.resume()
        update(.broadcasting)
    }

    func update(_ activity: BroadcastSharedSettings.Activity) {
        lock.lock()
        defer { lock.unlock() }
        self.activity = activity
        BroadcastSharedSettings.writeActivity(activity)
    }

    func stop() {
        update(.idle)
        timer?.cancel()
        timer = nil
    }

    deinit { stop() }
}

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
    private var activityReporter: BroadcastActivityReporter?
    private var didEnd = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        setStopRequested(false)
        didEnd = false
        lastStopRequestToken = BroadcastSharedSettings.currentStopRequestToken()
        usageGate = BroadcastUsageGate()
        addStopObserver()
        guard usageGate?.canContinue() == true else {
            endBroadcast(Self.usageLimitReachedError)
            return
        }
        frameServer.start()
        activityReporter = BroadcastActivityReporter()
    }

    override func broadcastPaused() {
        usageGate?.pause()
        activityReporter?.update(.paused)
    }

    override func broadcastResumed() {
        usageGate?.resume()
        activityReporter?.update(.broadcasting)
    }

    override func broadcastFinished() {
        activityReporter?.stop()
        activityReporter = nil
        usageGate?.finish()
        usageGate = nil
        removeStopObserver()
        frameServer.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
        if shouldStopBroadcast() {
            endBroadcast(Self.userStoppedBroadcastError)
            return
        }
        guard usageGate?.canContinue() == true else {
            endBroadcast(Self.usageLimitReachedError)
            return
        }
        guard frameServer.canAcceptFrame else { return }

        let profile = frameServer.captureProfile
        let presentationTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if lastEncodedFrameTime != .zero {
            let elapsed = CMTimeGetSeconds(CMTimeSubtract(presentationTime, lastEncodedFrameTime))
            guard elapsed >= profile.minimumFrameInterval else { return }
        }
        lastEncodedFrameTime = presentationTime

        autoreleasepool {
            guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            var ciImage = CIImage(cvPixelBuffer: imageBuffer)
            if let orientation = CMGetAttachment(sampleBuffer, key: RPVideoSampleOrientationKey as CFString, attachmentModeOut: nil) as? NSNumber,
               (1...8).contains(orientation.intValue) {
                ciImage = ciImage.oriented(forExifOrientation: orientation.int32Value)
            }
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
        if let token = BroadcastSharedSettings.currentStopRequestToken(), token != lastStopRequestToken {
            lastStopRequestToken = token
            stopRequested = true
        }
        return stopRequested
    }

    private func endBroadcast(_ error: NSError) {
        stopLock.lock()
        guard !didEnd else { stopLock.unlock(); return }
        didEnd = true
        stopLock.unlock()
        activityReporter?.stop()
        usageGate?.finish()
        frameServer.stop()
        finishBroadcastWithError(error)
    }

    private func setStopRequested(_ requested: Bool) {
        stopLock.lock()
        stopRequested = requested
        stopLock.unlock()
    }

    private func receiveStopNotification() {
        stopLock.lock()
        guard let token = BroadcastSharedSettings.currentStopRequestToken(), token != lastStopRequestToken else {
            stopLock.unlock()
            return
        }
        lastStopRequestToken = token
        stopRequested = true
        stopLock.unlock()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.shouldStopBroadcast() else { return }
            self.endBroadcast(Self.userStoppedBroadcastError)
        }
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

    private static let stopNotificationName = CFNotificationName("com.raccoonmerchant.ipadmirror.stopBroadcast" as CFString)

    private static let stopNotificationCallback: CFNotificationCallback = { _, observer, _, _, _ in
        guard let observer else { return }
        let handler = Unmanaged<SampleHandler>.fromOpaque(observer).takeUnretainedValue()
        // Paused broadcasts have no video callbacks. Finish from the
        // notification as well, so Stop also works while paused/no Mac.
        handler.receiveStopNotification()
    }
    private static let userStoppedBroadcastError = NSError(
        domain: "com.raccoonmerchant.ipadmirror.broadcast",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: MirrorL10n.text("사용자가 iPad 앱에서 화면 공유를 종료했습니다.")]
    )
    private static let usageLimitReachedError = NSError(
        domain: "com.raccoonmerchant.ipadmirror.usage",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: MirrorL10n.text("무료 사용 시간이 끝났습니다. iPad 앱에서 시간을 연장하거나 영구 사용을 구매하세요.")]
    )
}
