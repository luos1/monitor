import XCTest
import iPadMirrorShared

final class StoreEntitlementPolicyTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_791_036_000)

    func testBothNonConsumableProductsGrantLifetime() {
        for productID in MonetizationConfig.productIDs {
            XCTAssertTrue(grants(productID: productID))
        }
    }

    func testRefundAndRevocationDoNotGrantLifetime() {
        for productID in MonetizationConfig.productIDs {
            XCTAssertFalse(grants(productID: productID, revokedAt: now))
        }
    }

    func testExpiredAndUpgradedTransactionsDoNotGrantLifetime() {
        XCTAssertFalse(grants(expiresAt: now.addingTimeInterval(-1)))
        XCTAssertFalse(grants(expiresAt: now))
        XCTAssertFalse(grants(upgraded: true))
        XCTAssertTrue(grants(expiresAt: now.addingTimeInterval(1)))
    }

    func testUnrelatedAndOldProductIDsDoNotGrantLifetime() {
        XCTAssertFalse(grants(productID: "unknown.product"))
        XCTAssertFalse(grants(productID: "dev.local.iPadMirrorPad.pro.yearly"))
    }

    private func grants(
        productID: String = MonetizationConfig.lifetimeProductID,
        revokedAt: Date? = nil,
        expiresAt: Date? = nil,
        upgraded: Bool = false
    ) -> Bool {
        StoreEntitlementPolicy.grantsLifetime(
            productID: productID, revocationDate: revokedAt,
            expirationDate: expiresAt, isUpgraded: upgraded, now: now
        )
    }
}
