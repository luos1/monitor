import XCTest
@testable import iPadMirrorMac
@testable import iPadMirrorShared

@MainActor
final class UsageAccessManagerTests: XCTestCase {
    func testUsageLockAdExtensionAndLifetimeUnlock() {
        let namespace = "test.\(UUID().uuidString)"
        let manager = UsageAccessManager(namespace: namespace, freeLimitMinutes: 1)

        manager.resetForTesting()
        XCTAssertFalse(manager.isLocked)
        XCTAssertEqual(manager.remainingSeconds, 60)

        manager.simulateConsumed(seconds: 60)
        XCTAssertTrue(manager.isLocked)
        XCTAssertEqual(manager.remainingSeconds, 0)

        manager.grantAdExtension(minutes: 1)
        XCTAssertFalse(manager.isLocked)
        XCTAssertEqual(manager.remainingSeconds, 60)

        manager.simulateConsumed(seconds: 120)
        XCTAssertTrue(manager.isLocked)
        XCTAssertEqual(manager.remainingSeconds, 0)

        manager.setLifetimeEntitlement(true)
        XCTAssertFalse(manager.isLocked)
        XCTAssertEqual(manager.remainingTimeLabel, MirrorL10n.text("무제한"))
    }

    func testRemainingTimeLabelFormatting() {
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 0, lifetimeUnlocked: false, language: "ko"), "0초")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 45, lifetimeUnlocked: false, language: "ko"), "45초")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 125, lifetimeUnlocked: false, language: "ko"), "2분 5초")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 3720, lifetimeUnlocked: false, language: "ko"), "1시간 2분")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 0, lifetimeUnlocked: true, language: "ko"), "무제한")
    }

    func testRewardSurvivesRelaunchAndIsCapped() {
        let suite = "test.reward.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let manager = UsageAccessManager(namespace: "reward", maximumBonusHours: 2, suiteName: suite)
        manager.simulateConsumed(seconds: 3600)
        XCTAssertTrue(manager.isLocked)
        manager.grantAdExtension(minutes: 60)
        manager.grantAdExtension(minutes: 60)
        manager.grantAdExtension(minutes: 60)
        XCTAssertEqual(manager.bonusSeconds, 7200)
        let relaunched = UsageAccessManager(namespace: "reward", maximumBonusHours: 2, suiteName: suite)
        XCTAssertFalse(relaunched.isLocked)
        XCTAssertEqual(relaunched.remainingSeconds, 7200)
        XCTAssertEqual(relaunched.usedSeconds, 3600)
        XCTAssertFalse(relaunched.lifetimeUnlocked)
    }

    func testPersistedDefaultsCannotForgeLifetimeEntitlement() {
        let namespace = "test.entitlement.\(UUID().uuidString)"
        UserDefaults.standard.set(true, forKey: "\(namespace).usage.lifetimeUnlocked")

        let manager = UsageAccessManager(namespace: namespace, freeLimitMinutes: 1)

        XCTAssertFalse(manager.lifetimeUnlocked)
        XCTAssertNil(UserDefaults.standard.object(forKey: "\(namespace).usage.lifetimeUnlocked"))
    }
}
