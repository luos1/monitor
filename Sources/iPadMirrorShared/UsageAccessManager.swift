import Foundation
import SwiftUI

@MainActor
public final class UsageAccessManager: ObservableObject {
    @Published public private(set) var isLocked = false
    @Published public private(set) var remainingSeconds: Int
    @Published public private(set) var usedSeconds: Int
    @Published public private(set) var lifetimeUnlocked: Bool
    @Published public private(set) var bonusSeconds: Int

    public let namespace: String
    public let freeLimitSeconds: Int
    public let maximumBonusSeconds: Int

    private let defaults: UserDefaults
    private var activeSessionStartedAt: Date?
    private var timer: Timer?
    private var storedUsedSeconds: Int

    public init(
        namespace: String,
        freeLimitMinutes: Int = 60,
        maximumBonusHours: Int = 24,
        suiteName: String? = nil
    ) {
        self.namespace = namespace
        self.freeLimitSeconds = freeLimitMinutes * 60
        self.maximumBonusSeconds = max(0, maximumBonusHours) * 60 * 60
        if let suiteName, let suiteDefaults = UserDefaults(suiteName: suiteName) {
            self.defaults = suiteDefaults
        } else {
            self.defaults = .standard
        }
        let loadedBonusSeconds = min(
            maximumBonusSeconds,
            max(0, defaults.integer(forKey: "\(namespace).usage.bonusSeconds"))
        )
        self.storedUsedSeconds = defaults.integer(forKey: "\(namespace).usage.usedSeconds")
        self.bonusSeconds = loadedBonusSeconds
        self.lifetimeUnlocked = false
        self.usedSeconds = storedUsedSeconds
        self.remainingSeconds = max(0, freeLimitSeconds + loadedBonusSeconds - storedUsedSeconds)
        defaults.removeObject(forKey: "\(namespace).usage.lifetimeUnlocked")
        refreshState()
    }

    public func startTracking() {
        guard timer == nil else { return }
        activeSessionStartedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.persistActiveSessionIfNeeded()
                self?.refreshState()
            }
        }
        RunLoop.main.add(timer!, forMode: .common)
        refreshState()
    }

    public func stopTracking() {
        persistActiveSessionIfNeeded()
        timer?.invalidate()
        timer = nil
        activeSessionStartedAt = nil
        refreshState()
    }

    func grantAdExtension(minutes: Int = 60) {
        bonusSeconds = min(maximumBonusSeconds, bonusSeconds + max(0, minutes) * 60)
        defaults.set(bonusSeconds, forKey: "\(namespace).usage.bonusSeconds")
        refreshState()
    }

    func unlockLifetime() {
        setLifetimeEntitlement(true)
    }

    public func setLifetimeEntitlement(_ isUnlocked: Bool) {
        lifetimeUnlocked = isUnlocked
        defaults.removeObject(forKey: "\(namespace).usage.lifetimeUnlocked")
        refreshState()
    }

    public func reloadStoredUsage() {
        persistActiveSessionIfNeeded()
        storedUsedSeconds = defaults.integer(forKey: "\(namespace).usage.usedSeconds")
        bonusSeconds = min(
            maximumBonusSeconds,
            max(0, defaults.integer(forKey: "\(namespace).usage.bonusSeconds"))
        )
        activeSessionStartedAt = timer == nil ? nil : Date()
        refreshState()
    }

    #if DEBUG
    public func resetForTesting() {
        storedUsedSeconds = 0
        bonusSeconds = 0
        lifetimeUnlocked = false
        defaults.set(0, forKey: "\(namespace).usage.usedSeconds")
        defaults.set(0, forKey: "\(namespace).usage.bonusSeconds")
        defaults.removeObject(forKey: "\(namespace).usage.lifetimeUnlocked")
        activeSessionStartedAt = Date()
        refreshState()
    }

    public func simulateConsumed(seconds: Int) {
        storedUsedSeconds = max(0, seconds)
        defaults.set(storedUsedSeconds, forKey: "\(namespace).usage.usedSeconds")
        refreshState()
    }
    #endif

    public var remainingTimeLabel: String {
        Self.formatRemaining(seconds: remainingSeconds, lifetimeUnlocked: lifetimeUnlocked)
    }

    public var usageProgress: Double {
        let limit = Double(freeLimitSeconds + bonusSeconds)
        guard limit > 0 else { return 1 }
        return min(1, Double(usedSeconds) / limit)
    }

    public static func formatRemaining(seconds: Int, lifetimeUnlocked: Bool, language: String? = nil) -> String {
        if lifetimeUnlocked {
            return MirrorL10n.text("무제한", language: language)
        }

        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainSeconds = clamped % 60

        if hours > 0 {
            return MirrorL10n.format("{0}시간 {1}분", String(describing: hours), String(describing: minutes), language: language)
        }
        if minutes > 0 {
            return MirrorL10n.format("{0}분 {1}초", String(describing: minutes), String(describing: remainSeconds), language: language)
        }
        return MirrorL10n.format("{0}초", String(describing: remainSeconds), language: language)
    }

    private func refreshState() {
        let activeElapsed = activeSessionStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
        usedSeconds = storedUsedSeconds + activeElapsed
        let effectiveLimit = freeLimitSeconds + bonusSeconds
        remainingSeconds = max(0, effectiveLimit - usedSeconds)
        isLocked = !lifetimeUnlocked && usedSeconds >= effectiveLimit
    }

    private func persistActiveSessionIfNeeded() {
        guard let activeSessionStartedAt else { return }
        let activeElapsed = Int(Date().timeIntervalSince(activeSessionStartedAt))
        storedUsedSeconds += max(0, activeElapsed)
        defaults.set(storedUsedSeconds, forKey: "\(namespace).usage.usedSeconds")
        self.activeSessionStartedAt = Date()
    }
}
