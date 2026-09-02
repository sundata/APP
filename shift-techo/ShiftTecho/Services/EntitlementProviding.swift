import Foundation
import StoreKit

/// StoreKit 2 を使った「シフト手帳プレミアム」の購入・復元・権利管理。
@MainActor
@Observable
final class StoreKitEntitlementProvider {
    enum ProductID {
        static let monthly = "jp.co.sundata.shifttecho.premium.monthly"
        static let yearly = "jp.co.sundata.shifttecho.premium.yearly"
        static let lifetime = "jp.co.sundata.shifttecho.premium.lifetime"
        static let all: Set<String> = [monthly, yearly, lifetime]
    }

    private(set) var isPro = false
    private(set) var products: [Product] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private let isTesting: Bool

    init(isTesting: Bool = false) { self.isTesting = isTesting }

    func prepare() async {
        guard !isTesting else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: ProductID.all).sorted(by: productOrder)
            await refreshEntitlements()
        } catch {
            errorMessage = "商品情報を取得できませんでした。通信環境を確認して、もう一度お試しください。"
        }
    }

    func purchase(_ product: Product) async -> Bool {
        errorMessage = nil
        do {
            switch try await product.purchase() {
            case .success(let verification):
                let transaction = try verified(verification)
                await transaction.finish()
                await refreshEntitlements()
                return isPro
            case .pending, .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = "購入を完了できませんでした。時間をおいて、もう一度お試しください。"
            return false
        }
    }

    func restore() async {
        errorMessage = nil
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPro { errorMessage = "復元できる購入が見つかりませんでした。" }
        } catch {
            errorMessage = "購入を復元できませんでした。"
        }
    }

    func observeTransactions() async {
        guard !isTesting else { return }
        for await result in Transaction.updates {
            guard let transaction = try? verified(result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verified(result),
                  ProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            entitled = true
            break
        }
        isPro = entitled
    }

    private func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): value
        case .unverified: throw StoreKitError.failedVerification
        }
    }

    private func productOrder(_ lhs: Product, _ rhs: Product) -> Bool {
        let order = [ProductID.yearly, ProductID.monthly, ProductID.lifetime]
        return (order.firstIndex(of: lhs.id) ?? 99) < (order.firstIndex(of: rhs.id) ?? 99)
    }

    private enum StoreKitError: Error { case failedVerification }
}
