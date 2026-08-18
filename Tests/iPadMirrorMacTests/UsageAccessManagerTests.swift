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
        XCTAssertEqual(manager.remainingTimeLabel, "무제한")
    }

    func testRemainingTimeLabelFormatting() {
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 0, lifetimeUnlocked: false), "0초")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 45, lifetimeUnlocked: false), "45초")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 125, lifetimeUnlocked: false), "2분 5초")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 3720, lifetimeUnlocked: false), "1시간 2분")
        XCTAssertEqual(UsageAccessManager.formatRemaining(seconds: 0, lifetimeUnlocked: true), "무제한")
    }

    func testPersistedDefaultsCannotForgeLifetimeEntitlement() {
        let namespace = "test.entitlement.\(UUID().uuidString)"
        UserDefaults.standard.set(true, forKey: "\(namespace).usage.lifetimeUnlocked")

        let manager = UsageAccessManager(namespace: namespace, freeLimitMinutes: 1)

        XCTAssertFalse(manager.lifetimeUnlocked)
        XCTAssertNil(UserDefaults.standard.object(forKey: "\(namespace).usage.lifetimeUnlocked"))
    }
}
