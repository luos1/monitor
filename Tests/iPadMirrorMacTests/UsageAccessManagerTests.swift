import XCTest
@testable import iPadMirrorMac

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

        manager.unlockLifetime()
        XCTAssertFalse(manager.isLocked)
    }
}
