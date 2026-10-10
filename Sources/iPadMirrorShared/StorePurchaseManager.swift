import Foundation
import OSLog
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
    private let productLoader: @MainActor (Set<String>) async throws -> [Product]
    private let logger = Logger(subsystem: "com.raccoonmerchant.ipadmirror", category: "StoreProducts")

    public init(
        productLoader: @escaping @MainActor (Set<String>) async throws -> [Product] = {
            try await Product.products(for: $0)
        }
    ) {
        self.productLoader = productLoader
    }

    public var lifetimePriceLabel: String {
        priceLabel(for: lifetimeProduct)
    }

    public var donationPriceLabel: String {
        priceLabel(for: donationProduct)
    }

    private func priceLabel(for product: Product?) -> String {
        if let product { return product.displayPrice }
        return MirrorL10n.text(isLoadingProducts || !didLoadProducts ? "불러오는 중…" : "현재 이용 불가")
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
        statusMessage = nil
        defer {
            isLoadingProducts = false
            didLoadProducts = true
        }
        do {
            // A temporarily empty or incomplete catalog can recover after the
            // StoreKit service is ready. Keep retries bounded; never purchase
            // or sync the user's account as part of loading the catalog.
            for attempt in 1...3 {
                let products = try await productLoader(MonetizationConfig.productIDs)
                lifetimeProduct = products.first { $0.id == MonetizationConfig.lifetimeProductID }
                donationProduct = products.first { $0.id == MonetizationConfig.donationProductID }
                let missing = MonetizationConfig.productIDs.subtracting(products.map(\.id))
                logger.info("Product lookup attempt=\(attempt) returned=\(products.map(\.id).sorted().joined(separator: ","), privacy: .public) missing=\(missing.sorted().joined(separator: ","), privacy: .public)")
                if missing.isEmpty { return }
                if attempt < 3 {
                    try await Task.sleep(for: .milliseconds(500 * attempt))
                }
            }
            statusMessage = MirrorL10n.text(lifetimeProduct == nil && donationProduct == nil
                ? "스토어 상품을 아직 불러오지 못했습니다. Xcode StoreKit 구성 또는 App Store Connect 상품을 확인하세요."
                : "일부 구매 옵션을 불러오지 못했습니다. 다시 불러오세요.")
        } catch {
            let details = error as NSError
            logger.error("Product lookup failed domain=\(details.domain, privacy: .public) code=\(details.code)")
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
