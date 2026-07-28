import Foundation
import SwiftUI

@MainActor
final class UsageAccessManager: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var remainingSeconds: Int
    @Published private(set) var usedSeconds: Int
    @Published private(set) var lifetimeUnlocked: Bool
    @Published private(set) var bonusSeconds: Int

    let namespace: String
    let freeLimitSeconds: Int

    private let defaults: UserDefaults
    private var activeSessionStartedAt: Date?
    private var timer: Timer?
    private var storedUsedSeconds: Int

    init(namespace: String, freeLimitMinutes: Int = 60) {
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

    func startTracking() {
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

    func stopTracking() {
        persistActiveSessionIfNeeded()
        timer?.invalidate()
        timer = nil
        activeSessionStartedAt = nil
        refreshState()
    }

    func grantAdExtension(minutes: Int = 60) {
        bonusSeconds += max(0, minutes) * 60
        defaults.set(bonusSeconds, forKey: "\(namespace).usage.bonusSeconds")
        refreshState()
    }

    func unlockLifetime() {
        lifetimeUnlocked = true
        defaults.set(true, forKey: "\(namespace).usage.lifetimeUnlocked")
        refreshState()
    }

    func resetForTesting() {
        storedUsedSeconds = 0
        bonusSeconds = 0
        lifetimeUnlocked = false
        defaults.set(0, forKey: "\(namespace).usage.usedSeconds")
        defaults.set(0, forKey: "\(namespace).usage.bonusSeconds")
        defaults.set(false, forKey: "\(namespace).usage.lifetimeUnlocked")
        activeSessionStartedAt = Date()
        refreshState()
    }

    func simulateConsumed(seconds: Int) {
        storedUsedSeconds = max(0, seconds)
        defaults.set(storedUsedSeconds, forKey: "\(namespace).usage.usedSeconds")
        refreshState()
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
