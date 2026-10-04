import Foundation
import StoreKit
import SwiftUI

@MainActor
public final class StorePurchaseManager: ObservableObject {
    @Published public private(set) var lifetimeProduct: Product?
    @Published public private(set) var donationProduct: Product?
    @Published public private(set) var isPurchasing = false
    @Published public private(set) var isRestoring = false
    @Published public private(set) var isLoadingProducts = false
    @Published public private(set) var didLoadProducts = false
    @Published public private(set) var hasLifetimeEntitlement = false
    @Published public private(set) var didRefreshEntitlements = false
    @Published public var statusMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var didStart = false

    public init() {}

    public var lifetimePriceLabel: String {
        lifetimeProduct?.displayPrice ?? MirrorL10n.text("불러오는 중…")
    }

    public var donationPriceLabel: String {
        donationProduct?.displayPrice ?? MirrorL10n.text("불러오는 중…")
    }

    public var canPurchaseLifetime: Bool {
        lifetimeProduct != nil && !hasLifetimeEntitlement && !isPurchasing && !isRestoring
    }

    public var canPurchaseDonation: Bool {
        donationProduct != nil && !isPurchasing && !isRestoring
    }

    public var shouldRetryProducts: Bool {
        didLoadProducts && !isLoadingProducts && (lifetimeProduct == nil || donationProduct == nil)
    }

    public func start() {
        guard !didStart else { return }
        didStart = true
        updatesTask = Task { [weak self] in
            for await result in StoreKit.Transaction.updates {
                await self?.handle(result)
                await self?.refreshEntitlements()
            }
        }
        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    public func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer {
            isLoadingProducts = false
            didLoadProducts = true
        }
        do {
            let products = try await Product.products(for: MonetizationConfig.productIDs)
            lifetimeProduct = products.first { $0.id == MonetizationConfig.lifetimeProductID }
            donationProduct = products.first { $0.id == MonetizationConfig.donationProductID }
            if lifetimeProduct == nil && donationProduct == nil {
                statusMessage = MirrorL10n.text("스토어 상품을 아직 불러오지 못했습니다. Xcode StoreKit 구성 또는 App Store Connect 상품을 확인하세요.")
            } else {
                statusMessage = nil
            }
        } catch {
            statusMessage = MirrorL10n.format("스토어 상품 로드 실패: {0}", String(describing: MirrorL10n.errorMessage(error)))
        }
    }

    public func purchaseLifetime() async -> Bool {
        await purchase(lifetimeProduct, outcome: .lifetimeUnlocked)
    }

    public func purchaseDonation() async -> Bool {
        await purchase(donationProduct, outcome: .donationCompleted)
    }

    public func restore() async {
        guard !isRestoring && !isPurchasing else { return }
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasLifetimeEntitlement ? MirrorL10n.text("구매를 복원했습니다.") : MirrorL10n.text("복원할 영구 사용 구매가 없습니다.")
        } catch {
            statusMessage = MirrorL10n.format("복원 실패: {0}", String(describing: MirrorL10n.errorMessage(error)))
        }
    }

    public func refreshEntitlements() async {
        var unlocked = false
        for await result in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if grantsLifetime(transaction) {
                unlocked = true
            }
        }
        hasLifetimeEntitlement = unlocked
        didRefreshEntitlements = true
    }

    private func purchase(_ product: Product?, outcome: MonetizationOutcome) async -> Bool {
        guard !isPurchasing && !isRestoring else { return false }
        guard let product else {
            statusMessage = MirrorL10n.text("스토어 상품이 아직 준비되지 않았습니다.")
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard await handle(verification) else {
                    return false
                }
                if outcome == .donationCompleted {
                    statusMessage = MirrorL10n.text("후원해 주셔서 감사합니다. 영구 사용이 해제되었습니다.")
                } else {
                    statusMessage = MirrorL10n.text("영구 사용이 해제되었습니다.")
                }
                return true
            case .userCancelled:
                statusMessage = nil
                return false
            case .pending:
                statusMessage = MirrorL10n.text("구매가 승인 대기 중입니다.")
                return false
            @unknown default:
                statusMessage = MirrorL10n.text("알 수 없는 구매 결과입니다.")
                return false
            }
        } catch {
            statusMessage = MirrorL10n.format("구매 실패: {0}", String(describing: MirrorL10n.errorMessage(error)))
            return false
        }
    }

    @discardableResult
    private func handle(
        _ result: VerificationResult<StoreKit.Transaction>
    ) async -> Bool {
        guard case .verified(let transaction) = result else {
            statusMessage = MirrorL10n.text("구매 검증에 실패했습니다.")
            return false
        }

        guard MonetizationConfig.productIDs.contains(transaction.productID) else {
            statusMessage = MirrorL10n.text("알 수 없는 상품의 구매 결과입니다.")
            return false
        }

        await transaction.finish()
        await refreshEntitlements()
        guard grantsLifetime(transaction) else {
            statusMessage = MirrorL10n.text("이 구매는 현재 영구 사용 권한을 제공하지 않습니다.")
            return false
        }
        return true
    }

    private func grantsLifetime(_ transaction: StoreKit.Transaction) -> Bool {
        StoreEntitlementPolicy.grantsLifetime(
            productID: transaction.productID,
            revocationDate: transaction.revocationDate,
            expirationDate: transaction.expirationDate,
            isUpgraded: transaction.isUpgraded
        )
    }
}
