import XCTest
import StoreKit
import StoreKitTest
@testable import iPadMirrorPad

/// Explicit local StoreKit testing only; never connects to paid purchases.
@MainActor
final class StoreKitIntegrationTests: XCTestCase {
    private func session() async throws -> SKTestSession {
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.askToBuyEnabled = false
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        try await session.setSimulatedError(nil, forAPI: .purchase)
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        try await session.setSimulatedError(nil, forAPI: .verification)
        session.clearTransactions()
        // Check the app's local environment without making a bootstrap
        // purchase that could be reused by StoreKit's transaction cache.
        guard case .verified(let appTransaction) = try await AppTransaction.shared,
              appTransaction.environment == .xcode else {
            throw NSError(domain: "iPadMirrorQA", code: 1, userInfo: [NSLocalizedDescriptionKey: "Local Xcode StoreKit environment is required."])
        }
        for _ in 0..<50 {
            var hasEntitlement = false
            for await result in StoreKit.Transaction.currentEntitlements {
                if case .verified(let transaction) = result,
                   MonetizationConfig.productIDs.contains(transaction.productID) {
                    hasEntitlement = true
                }
            }
            if !hasEntitlement && session.allTransactions().isEmpty { return session }
            try await Task.sleep(for: .milliseconds(100))
        }
        throw NSError(domain: "iPadMirrorQA", code: 2, userInfo: [NSLocalizedDescriptionKey: "Local StoreKit state did not clear within five seconds."])
    }

    func testLocalCatalogMatchesConfiguration() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let products = try await Product.products(for: MonetizationConfig.productIDs)
        XCTAssertEqual(Set(products.map(\.id)), Set(MonetizationConfig.productIDs))
        XCTAssertEqual(Bundle.main.bundleIdentifier, "com.raccoonmerchant.ipadmirror")
        print("[Local StoreKit QA] environment=Xcode bundle=\(Bundle.main.bundleIdentifier ?? "nil") productIDs=\(products.map(\.id).sorted())")
    }

    /// Reads products before the AppTransaction guard to distinguish catalog
    /// setup from receipt/account failures. Never purchases or restores.
    func testLocalCatalogReadOnlyProbe() async throws {
        let configuration = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Products", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: configuration)
        session.resetToDefaultState()
        defer { withExtendedLifetime(session) {} }
        let products = try await Product.products(for: MonetizationConfig.productIDs)
        print("[StoreKit read-only probe] productIDs=\(products.map(\.id).sorted())")
        XCTAssertEqual(Set(products.map(\.id)), MonetizationConfig.productIDs)
        do {
            if case .verified(let transaction) = try await AppTransaction.shared {
                print("[StoreKit read-only probe] appEnvironment=\(transaction.environment)")
            }
        } catch {
            print("[StoreKit read-only probe] appTransactionError=\(error)")
        }
    }

    func testLocalLifetimePurchaseRestoreAndRefund() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = StorePurchaseManager()
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct, store.statusMessage ?? "")
        _ = try XCTUnwrap(store.donationProduct, store.statusMessage ?? "")
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasLifetimeEntitlement)
        let purchased = await store.purchaseLifetime()
        XCTAssertTrue(purchased, store.statusMessage ?? "")
        XCTAssertTrue(store.hasLifetimeEntitlement)

        let restored = StorePurchaseManager()
        await restored.restore()
        XCTAssertTrue(restored.hasLifetimeEntitlement, restored.statusMessage ?? "")
        XCTAssertFalse(restored.isRestoring)

        let transaction = try XCTUnwrap(session.allTransactions().first {
            $0.productIdentifier == MonetizationConfig.lifetimeProductID
        })
        try session.refundTransaction(identifier: transaction.identifier)
        // StoreKit broadcasts the revocation asynchronously; wait for the
        // authoritative entitlement state instead of racing that update.
        for _ in 0..<50 {
            await restored.refreshEntitlements()
            if !restored.hasLifetimeEntitlement { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertFalse(restored.hasLifetimeEntitlement)
    }

    func testLocalCancelledPurchaseDoesNotGrantEntitlement() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = StorePurchaseManager()
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct)
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: .purchase)
        let purchased = await store.purchaseLifetime()
        XCTAssertFalse(purchased)
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasLifetimeEntitlement)
        XCTAssertFalse(store.isPurchasing)
    }

    func testLocalDeveloperSupportGrantsLifetimeAndRestores() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = StorePurchaseManager()
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct, store.statusMessage ?? "")
        _ = try XCTUnwrap(store.donationProduct, store.statusMessage ?? "")
        let purchased = await store.purchaseDonation()
        XCTAssertTrue(purchased, store.statusMessage ?? "")
        XCTAssertTrue(store.hasLifetimeEntitlement)
        let restored = StorePurchaseManager()
        await restored.restore()
        XCTAssertTrue(restored.hasLifetimeEntitlement, restored.statusMessage ?? "")
    }

    func testLocalProductLoadErrorCanRecover() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .loadProducts)
        let store = StorePurchaseManager()
        await store.loadProducts()
        XCTAssertNil(store.lifetimeProduct)
        XCTAssertNotNil(store.statusMessage)
        XCTAssertFalse(store.hasLifetimeEntitlement)
        try await session.setSimulatedError(nil, forAPI: .loadProducts)
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct)
        _ = try XCTUnwrap(store.donationProduct)
        XCTAssertNil(store.statusMessage)
    }

    func testLocalEmptyCatalogCanRecoverWithRealProducts() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        var catalogAvailable = false
        let store = StorePurchaseManager { ids in
            if !catalogAvailable { return [] }
            return try await Product.products(for: ids)
        }
        await store.loadProducts()
        XCTAssertFalse(store.isLoadingProducts)
        XCTAssertEqual(store.lifetimePriceLabel, MirrorL10n.text("현재 이용 불가"))
        XCTAssertTrue(store.shouldRetryProducts)
        XCTAssertFalse(store.canPurchaseLifetime)

        catalogAvailable = true
        await store.loadProducts()
        let lifetime = try XCTUnwrap(store.lifetimeProduct)
        _ = try XCTUnwrap(store.donationProduct)
        XCTAssertEqual(store.lifetimePriceLabel, lifetime.displayPrice)
        XCTAssertTrue(store.canPurchaseLifetime)
        XCTAssertFalse(store.shouldRetryProducts)
        XCTAssertNil(store.statusMessage)
    }

    func testLocalPartialCatalogKeepsAvailableProductAndReportsMissingOne() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        var catalogComplete = false
        let store = StorePurchaseManager { ids in
            let products = try await Product.products(for: ids)
            return catalogComplete ? products : products.filter { $0.id == MonetizationConfig.lifetimeProductID }
        }
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct)
        XCTAssertNil(store.donationProduct)
        XCTAssertTrue(store.canPurchaseLifetime)
        XCTAssertFalse(store.canPurchaseDonation)
        XCTAssertTrue(store.shouldRetryProducts)
        XCTAssertNotNil(store.statusMessage)

        catalogComplete = true
        await store.loadProducts()
        _ = try XCTUnwrap(store.donationProduct)
        XCTAssertTrue(store.canPurchaseDonation)
        XCTAssertFalse(store.shouldRetryProducts)
        XCTAssertNil(store.statusMessage)
    }

    func testLocalPurchaseErrorDoesNotGrantEntitlement() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = StorePurchaseManager()
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct)
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .purchase)
        let purchased = await store.purchaseLifetime()
        XCTAssertFalse(purchased)
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasLifetimeEntitlement)
        XCTAssertFalse(store.isPurchasing)
        XCTAssertNotNil(store.statusMessage)
    }

    func testLocalRestoreErrorCanRecover() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        let store = StorePurchaseManager()
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct)
        let purchased = await store.purchaseLifetime()
        XCTAssertTrue(purchased)
        let restored = StorePurchaseManager()
        try await session.setSimulatedError(.generic(.networkError(URLError(.notConnectedToInternet))), forAPI: .appStoreSync)
        await restored.restore()
        XCTAssertFalse(restored.isRestoring)
        XCTAssertNotNil(restored.statusMessage)
        try await session.setSimulatedError(nil, forAPI: .appStoreSync)
        await restored.restore()
        XCTAssertTrue(restored.hasLifetimeEntitlement)
    }

    func testLocalPendingPurchaseRequiresApprovalAndSurvivesNewManager() async throws {
        let session = try await session()
        defer { session.clearTransactions() }
        session.askToBuyEnabled = true
        let store = StorePurchaseManager()
        await store.loadProducts()
        _ = try XCTUnwrap(store.lifetimeProduct)
        let purchased = await store.purchaseLifetime()
        XCTAssertFalse(purchased)
        await store.refreshEntitlements()
        XCTAssertFalse(store.hasLifetimeEntitlement)
        let pending = try XCTUnwrap(session.allTransactions().first { $0.pendingAskToBuyConfirmation })
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        let relaunched = StorePurchaseManager()
        for _ in 0..<50 {
            await relaunched.refreshEntitlements()
            if relaunched.hasLifetimeEntitlement { break }
            try await Task.sleep(for: .milliseconds(100))
        }
        XCTAssertTrue(relaunched.hasLifetimeEntitlement)
    }
}
