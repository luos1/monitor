import XCTest
import iPadMirrorShared

@MainActor
final class StoreProductLoadingTests: XCTestCase {
    func testEmptyCatalogStopsShowingLoadingAndAllowsRetry() async {
        var requests = 0
        let store = StorePurchaseManager { ids in
            XCTAssertEqual(ids, MonetizationConfig.productIDs)
            requests += 1
            return []
        }
        XCTAssertEqual(store.lifetimePriceLabel, MirrorL10n.text("불러오는 중…"))

        await store.loadProducts()

        XCTAssertEqual(requests, 3)
        XCTAssertTrue(store.didLoadProducts)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertTrue(store.shouldRetryProducts)
        XCTAssertEqual(store.lifetimePriceLabel, MirrorL10n.text("현재 이용 불가"))
        XCTAssertEqual(store.donationPriceLabel, MirrorL10n.text("현재 이용 불가"))
        XCTAssertFalse(store.canPurchaseLifetime)
        XCTAssertFalse(store.canPurchaseDonation)
        XCTAssertFalse(store.hasLifetimeEntitlement)
        XCTAssertNotNil(store.statusMessage)
    }

    func testLookupErrorEndsLoadingAndCanBeRetried() async {
        var shouldFail = true
        var requests = 0
        let store = StorePurchaseManager { _ in
            requests += 1
            if shouldFail { throw URLError(.notConnectedToInternet) }
            return []
        }

        await store.loadProducts()
        XCTAssertEqual(requests, 1)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertTrue(store.shouldRetryProducts)
        XCTAssertEqual(store.lifetimePriceLabel, MirrorL10n.text("현재 이용 불가"))
        XCTAssertNotNil(store.statusMessage)

        shouldFail = false
        await store.loadProducts()
        XCTAssertEqual(requests, 4)
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertFalse(store.hasLifetimeEntitlement)
    }

    func testConcurrentLoadsDoNotDuplicateCatalogRequests() async {
        var requests = 0
        let store = StorePurchaseManager { _ in
            requests += 1
            try await Task.sleep(for: .milliseconds(50))
            return []
        }
        let first = Task { await store.loadProducts() }
        while !store.isLoadingProducts { await Task.yield() }
        await store.loadProducts()
        await first.value
        XCTAssertEqual(requests, 3)
        XCTAssertFalse(store.isLoadingProducts)
    }
}
