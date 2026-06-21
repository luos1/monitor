import CoreGraphics
import CoreImage
import CoreMedia
import Foundation
import ImageIO
import ReplayKit

final class SampleHandler: RPBroadcastSampleHandler {
    private let frameServer = BroadcastFrameServer()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private var lastEncodedFrameTime = CMTime.zero
    private var stopRequested = false

    override func broadcastStarted(withSetupInfo setupInfo: [String: NSObject]?) {
        stopRequested = false
        addStopObserver()
        frameServer.start()
    }

    override func broadcastPaused() {
    }

    override func broadcastResumed() {
    }

    override func broadcastFinished() {
        removeStopObserver()
        frameServer.stop()
    }

    override func processSampleBuffer(_ sampleBuffer: CMSampleBuffer, with sampleBufferType: RPSampleBufferType) {
        guard sampleBufferType == .video else { return }
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
        stopRequested
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
        handler.stopRequested = true
    }
    private static let userStoppedBroadcastError = NSError(
        domain: "dev.local.iPadMirrorPad.broadcast",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "사용자가 iPad 앱에서 화면 공유를 종료했습니다."]
    )
}
