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

    private let defaults: UserDefaults
    private var activeSessionStartedAt: Date?
    private var timer: Timer?
    private var storedUsedSeconds: Int

    public init(namespace: String, freeLimitMinutes: Int = 60) {
        self.namespace = namespace
        self.freeLimitSeconds = freeLimitMinutes * 60
        self.defaults = UserDefaults.standard
        let loadedBonusSeconds = defaults.integer(forKey: "\(namespace).usage.bonusSeconds")
        let loadedLifetimeUnlocked = defaults.bool(forKey: "\(namespace).usage.lifetimeUnlocked")
        self.storedUsedSeconds = defaults.integer(forKey: "\(namespace).usage.usedSeconds")
        self.bonusSeconds = loadedBonusSeconds
        self.lifetimeUnlocked = loadedLifetimeUnlocked
        self.usedSeconds = storedUsedSeconds
        self.remainingSeconds = max(0, freeLimitSeconds + loadedBonusSeconds - storedUsedSeconds)
        refreshState()
    }

    public func startTracking() {
        guard timer == nil else { return }
        activeSessionStartedAt = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
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

    public func grantAdExtension(minutes: Int = 60) {
        bonusSeconds += max(0, minutes) * 60
        defaults.set(bonusSeconds, forKey: "\(namespace).usage.bonusSeconds")
        refreshState()
    }

    public func unlockLifetime() {
        setLifetimeUnlocked(true)
    }

    public func setLifetimeUnlocked(_ unlocked: Bool) {
        lifetimeUnlocked = unlocked
        defaults.set(unlocked, forKey: "\(namespace).usage.lifetimeUnlocked")
        refreshState()
    }

    public func resetForTesting() {
        storedUsedSeconds = 0
        bonusSeconds = 0
        lifetimeUnlocked = false
        defaults.set(0, forKey: "\(namespace).usage.usedSeconds")
        defaults.set(0, forKey: "\(namespace).usage.bonusSeconds")
        defaults.set(false, forKey: "\(namespace).usage.lifetimeUnlocked")
        activeSessionStartedAt = Date()
        refreshState()
    }

    public func simulateConsumed(seconds: Int) {
        storedUsedSeconds = max(0, seconds)
        defaults.set(storedUsedSeconds, forKey: "\(namespace).usage.usedSeconds")
        refreshState()
    }

    public var remainingTimeLabel: String {
        Self.formatRemaining(seconds: remainingSeconds, lifetimeUnlocked: lifetimeUnlocked)
    }

    public var usageProgress: Double {
        let limit = Double(freeLimitSeconds + bonusSeconds)
        guard limit > 0 else { return 1 }
        return min(1, Double(usedSeconds) / limit)
    }

    public static func formatRemaining(seconds: Int, lifetimeUnlocked: Bool) -> String {
        if lifetimeUnlocked {
            return "무제한"
        }

        let clamped = max(0, seconds)
        let hours = clamped / 3600
        let minutes = (clamped % 3600) / 60
        let remainSeconds = clamped % 60

        if hours > 0 {
            return "\(hours)시간 \(minutes)분"
        }
        if minutes > 0 {
            return "\(minutes)분 \(remainSeconds)초"
        }
        return "\(remainSeconds)초"
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
    }
}
