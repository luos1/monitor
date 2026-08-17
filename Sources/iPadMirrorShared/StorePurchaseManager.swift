import Foundation
import StoreKit
import SwiftUI

@MainActor
public final class StorePurchaseManager: ObservableObject {
    @Published public private(set) var lifetimeProduct: Product?
    @Published public private(set) var donationProduct: Product?
    @Published public private(set) var isPurchasing = false
    @Published public private(set) var isRestoring = false
    @Published public private(set) var hasLifetimeEntitlement = false
    @Published public var statusMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var didStart = false

    public init() {}

    public var lifetimePriceLabel: String {
        lifetimeProduct?.displayPrice ?? MonitorTheme.lifetimePrice
    }

    public var donationPriceLabel: String {
        donationProduct?.displayPrice ?? MonitorTheme.donationPrice
    }

    public var canPurchaseLifetime: Bool {
        lifetimeProduct != nil && !hasLifetimeEntitlement && !isPurchasing
    }

    public var canPurchaseDonation: Bool {
        donationProduct != nil && !isPurchasing
    }

    public func start() {
        guard !didStart else { return }
        didStart = true
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
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
        do {
            let products = try await Product.products(for: MonetizationConfig.productIDs)
            lifetimeProduct = products.first { $0.id == MonetizationConfig.lifetimeProductID }
            donationProduct = products.first { $0.id == MonetizationConfig.donationProductID }
            if lifetimeProduct == nil && donationProduct == nil {
                statusMessage = "스토어 상품을 아직 불러오지 못했습니다. Xcode StoreKit 구성 또는 App Store Connect 상품을 확인하세요."
            }
        } catch {
            statusMessage = "스토어 상품 로드 실패: \(error.localizedDescription)"
        }
    }

    public func purchaseLifetime() async -> Bool {
        await purchase(lifetimeProduct, outcome: .lifetimeUnlocked)
    }

    public func purchaseDonation() async -> Bool {
        await purchase(donationProduct, outcome: .donationCompleted)
    }

    public func restore() async {
        isRestoring = true
        defer { isRestoring = false }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            statusMessage = hasLifetimeEntitlement ? "구매를 복원했습니다." : "복원할 영구 사용 구매가 없습니다."
        } catch {
            statusMessage = "복원 실패: \(error.localizedDescription)"
        }
    }

    public func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == MonetizationConfig.lifetimeProductID {
                unlocked = true
            }
        }
        hasLifetimeEntitlement = unlocked
    }

    private func purchase(_ product: Product?, outcome: MonetizationOutcome) async -> Bool {
        guard let product else {
            statusMessage = "스토어 상품이 아직 준비되지 않았습니다."
            return false
        }

        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                await handle(verification)
                if outcome == .donationCompleted {
                    hasLifetimeEntitlement = true
                    statusMessage = "후원해 주셔서 감사합니다. 영구 사용이 해제되었습니다."
                } else {
                    statusMessage = "영구 사용이 해제되었습니다."
                }
                return true
            case .userCancelled:
                statusMessage = nil
                return false
            case .pending:
                statusMessage = "구매가 승인 대기 중입니다."
                return false
            @unknown default:
                statusMessage = "알 수 없는 구매 결과입니다."
                return false
            }
        } catch {
            statusMessage = "구매 실패: \(error.localizedDescription)"
            return false
        }
    }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = result else {
            statusMessage = "구매 검증에 실패했습니다."
            return
        }

        if transaction.productID == MonetizationConfig.lifetimeProductID {
            hasLifetimeEntitlement = true
        }

        await transaction.finish()
    }
}
