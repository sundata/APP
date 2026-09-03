import Foundation
import Observation
import StoreKit

@MainActor
@Observable
final class MembershipStore {
    static let monthlyID = "jp.co.sundata.swimfinder.plus.monthly"
    static let yearlyID = "jp.co.sundata.swimfinder.plus.yearly"
    static let freeAthleteLimit = 2

    private(set) var products: [Product] = []
    private(set) var isPlus = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var updatesTask: Task<Void, Never>?
    private let usesTestEntitlement: Bool

    init(isUITesting: Bool, forcesFreeTier: Bool = false) {
        usesTestEntitlement = isUITesting
        isPlus = isUITesting && !forcesFreeTier
        guard !isUITesting else { return }
        updatesTask = Task { [weak self] in await self?.observeTransactions() }
        Task { await load() }
    }

    func load() async {
        guard !usesTestEntitlement else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [Self.monthlyID, Self.yearlyID])
                .sorted { $0.price < $1.price }
            await refreshEntitlement()
            errorMessage = products.isEmpty ? "購入商品を取得できませんでした。App Store の設定完了後に再度お試しください。" : nil
        } catch {
            errorMessage = "会員情報を読み込めませんでした。通信環境を確認してください。"
        }
    }

    func purchase(_ product: Product) async {
        isLoading = true
        defer { isLoading = false }
        do {
            switch try await product.purchase() {
            case let .success(result):
                guard case let .verified(transaction) = result else {
                    errorMessage = "購入情報を確認できませんでした。"
                    return
                }
                await transaction.finish()
                await refreshEntitlement()
            case .pending:
                errorMessage = "購入は承認待ちです。承認後に自動で反映されます。"
            case .userCancelled:
                break
            @unknown default:
                errorMessage = "購入を完了できませんでした。"
            }
        } catch {
            errorMessage = "購入を完了できませんでした。"
        }
    }

    func restore() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await refreshEntitlement()
            if !isPlus { errorMessage = "有効な購入は見つかりませんでした。" }
        } catch {
            errorMessage = "購入履歴を復元できませんでした。"
        }
    }

    func clearError() { errorMessage = nil }

    private func refreshEntitlement() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            guard case let .verified(transaction) = result,
                  transaction.revocationDate == nil,
                  transaction.expirationDate.map({ $0 > Date() }) ?? true,
                  [Self.monthlyID, Self.yearlyID].contains(transaction.productID) else { continue }
            active = true
        }
        isPlus = active
    }

    private func observeTransactions() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            if case let .verified(transaction) = result { await transaction.finish() }
            await refreshEntitlement()
        }
    }
}
