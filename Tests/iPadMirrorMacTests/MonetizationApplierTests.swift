import XCTest
@testable import iPadMirrorMac
import iPadMirrorShared

@MainActor
final class MonetizationApplierTests: XCTestCase {
    func testRewardedAdExtendsFreeTime() {
        let usage = UsageAccessManager(namespace: "test.ad.\(UUID().uuidString)", freeLimitMinutes: 1)
        usage.resetForTesting()
        usage.simulateConsumed(seconds: 60)
        XCTAssertTrue(usage.isLocked)

        MonetizationApplier.apply(.rewardedAdFinished, to: usage)

        XCTAssertFalse(usage.isLocked)
        XCTAssertEqual(usage.remainingSeconds, 60)
    }

    func testLifetimeAndDonationUnlock() {
        let usage = UsageAccessManager(namespace: "test.iap.\(UUID().uuidString)", freeLimitMinutes: 1)
        usage.resetForTesting()
        usage.simulateConsumed(seconds: 60)
        XCTAssertTrue(usage.isLocked)

        MonetizationApplier.apply(.lifetimeUnlocked, to: usage)
        XCTAssertFalse(usage.isLocked)
        XCTAssertTrue(usage.lifetimeUnlocked)

        usage.resetForTesting()
        usage.simulateConsumed(seconds: 60)
        MonetizationApplier.apply(.donationCompleted, to: usage)
        XCTAssertTrue(usage.lifetimeUnlocked)
        XCTAssertFalse(usage.isLocked)
    }

    func testProductIdentifiers() {
        XCTAssertEqual(MonetizationConfig.lifetimeProductID, "ipadmirror.lifetime")
        XCTAssertEqual(MonetizationConfig.donationProductID, "ipadmirror.donation")
        XCTAssertTrue(MonetizationConfig.productIDs.contains(MonetizationConfig.lifetimeProductID))
        XCTAssertFalse(MonetizationConfig.usesGoogleSampleAds)
    }
}
