import Foundation
import StoreKit
import SwiftUI

@MainActor
public final class StorePurchaseManager: ObservableObject {
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var isBusy = false
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var hasLifetimeEntitlement = false
    @Published public private(set) var didResolveEntitlements = false

    private var updatesTask: Task<Void, Never>?

    public init() {}

    deinit {
        updatesTask?.cancel()
    }

    public func start() async {
        if updatesTask == nil {
            updatesTask = listenForTransactions()
        }
        await loadProducts()
        await refreshEntitlements()
    }

    public func loadProducts() async {
        do {
            let loaded = try await Product.products(for: IAPProductID.allIDs)
            products = loaded.sorted { $0.price < $1.price }
            if loaded.isEmpty {
                statusMessage = "스토어에서 상품을 찾지 못했습니다. 네트워크와 App Store 계정을 확인해 주세요."
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    public func product(for id: IAPProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    public func displayName(for id: IAPProductID) -> String {
        product(for: id)?.displayName ?? id.fallbackDisplayName
    }

    public func displayPrice(for id: IAPProductID) -> String {
        product(for: id)?.displayPrice ?? id.fallbackPriceLabel
    }

    @discardableResult
    public func purchase(_ id: IAPProductID) async -> Bool {
        statusMessage = nil
        if product(for: id) == nil {
            await loadProducts()
        }
        guard let product = product(for: id) else {
            statusMessage = "상품 정보를 불러오지 못했습니다."
            return false
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                return await refreshEntitlements()
            case .userCancelled:
                return false
            case .pending:
                statusMessage = "결제가 대기 중입니다. 승인되면 자동으로 해제됩니다."
                return false
            @unknown default:
                statusMessage = "구매를 완료하지 못했습니다."
                return false
            }
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func restorePurchases() async -> Bool {
        statusMessage = nil
        isBusy = true
        defer { isBusy = false }

        do {
            try await AppStore.sync()
            let entitled = await refreshEntitlements()
            if !entitled {
                statusMessage = "복원할 구매 내역이 없습니다."
            }
            return entitled
        } catch {
            statusMessage = error.localizedDescription
            return false
        }
    }

    @discardableResult
    public func refreshEntitlements() async -> Bool {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else { continue }
            if IAPProductID(rawValue: transaction.productID)?.grantsLifetimeUnlock == true {
                unlocked = true
            }
        }
        hasLifetimeEntitlement = unlocked
        didResolveEntitlements = true
        return unlocked
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await result in Transaction.updates {
                guard let transaction = try? Self.verified(result) else { continue }
                await transaction.finish()
                await self?.refreshEntitlements()
            }
        }
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

private struct StoreEntitlementSyncModifier: ViewModifier {
    @ObservedObject var store: StorePurchaseManager
    @ObservedObject var usageAccess: UsageAccessManager

    func body(content: Content) -> some View {
        content
            .task {
                await store.start()
                applyEntitlement()
            }
            .onChange(of: store.hasLifetimeEntitlement) { _, _ in
                applyEntitlement()
            }
            .onChange(of: store.didResolveEntitlements) { _, _ in
                applyEntitlement()
            }
    }

    private func applyEntitlement() {
        guard store.didResolveEntitlements else { return }
        usageAccess.setLifetimeUnlocked(store.hasLifetimeEntitlement)
    }
}

public extension View {
    func syncsLifetimeUnlock(
        from store: StorePurchaseManager,
        to usageAccess: UsageAccessManager
    ) -> some View {
        modifier(StoreEntitlementSyncModifier(store: store, usageAccess: usageAccess))
    }
}
