import SwiftUI
import StoreKit

// MARK: - IAP 商品定義
enum IAPProduct {
    /// 一度限りの購入：永久に広告なし
    static let removeAds = "com.sundata.newsnow.premiumlifetime"
}

// MARK: - StoreKit 2 管理器
@MainActor
final class StoreManager: ObservableObject {
    static let shared = StoreManager()

    // ── 商品リスト ──
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var purchaseError: String?

    // ── 購入済み判定 ──
    var isPremiumUser: Bool {
        !purchasedProductIDs.isEmpty
    }

    // ── トランザクション監視 ──
    private var transactionListener: Task<Void, Never>?
    private var lastProductLoadAttempt: Date?

    private init() {
        // トランザクション監視開始
        transactionListener = listenForTransactions()
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - 商品読み込み
    func loadProducts(force: Bool = false) async {
        guard !isLoading else { return }
        if !force, !products.isEmpty { return }
        isLoading = true
        lastProductLoadAttempt = Date()
        purchaseError = nil
        defer { isLoading = false }

        do {
            let storeProducts = try await Product.products(for: [
                IAPProduct.removeAds
            ])
            
            self.products = storeProducts
            print("[StoreManager] ✅ Loaded \(storeProducts.count) product(s)")
            
            if storeProducts.isEmpty {
                print("[StoreManager] ⚠️ No products loaded! Check Product ID in App Store Connect")
                self.purchaseError = "購入情報を読み込めませんでした。通信状態を確認して、再読み込みしてください。"
            }

            // 現在の購入状態を確認
            await updatePurchasedStatus()
        } catch {
            print("[StoreManager] ❌ Failed to load products: \(error.localizedDescription)")
            self.purchaseError = "購入情報の取得に失敗しました。再読み込みしてください。"
        }
    }

    // MARK: - 購入
    func purchase(_ product: Product) async -> Bool {
        do {
            print("[StoreManager] 🛒 purchasing product: \(product.id), price: \(product.displayPrice)")
            
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                print("[StoreManager] ✅ Purchase successful!")
                let transaction = try checkVerified(verification)

                // 購入状態更新
                await updatePurchasedStatus()

                // トランザクション完了
                await transaction.finish()
                print("[StoreManager] ✅ Transaction finished")
                return true

            case .userCancelled:
                print("[StoreManager] ⚠️ Purchase cancelled by user")
                self.purchaseError = nil
                return false

            case .pending:
                print("[StoreManager] ⏳ Purchase pending (requires approval)")
                self.purchaseError = "購入が保留中です。承認後に有効になります。"
                return false

            @unknown default:
                print("[StoreManager] ❌ Unknown purchase result")
                return false
            }
        } catch {
            print("[StoreManager] ❌ Purchase error: \(error.localizedDescription)")
            self.purchaseError = "購入に失敗しました: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - 復元
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedStatus()
        } catch {
            print("[StoreManager] Restore error: \(error)")
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - 購入状態更新
    private func updatePurchasedStatus() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                purchasedIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchasedIDs
        print("[StoreManager] Purchased products: \(purchasedIDs)")
    }

    // MARK: - トランザクション監視
    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                if case .verified(let transaction) = result {
                    await self.updatePurchasedStatus()
                    await transaction.finish()
                }
            }
        }
    }

    // MARK: - 検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - 通知名
extension Notification.Name {
    static let premiumStatusDidChange = Notification.Name("premiumStatusDidChange")
}

// MARK: - エラー
enum StoreError: Error {
    case failedVerification
}

// MARK: - Product 拡張
extension Product {
    /// 表示用価格文字列（¥500 等）
    var displayPrice: String {
        price.formatted(.currency(code: Locale.current.currency?.identifier ?? "JPY"))
    }

    /// サブスクリプション期間の表示名
    var subscriptionPeriodText: String? {
        guard let sub = subscription else { return nil }
        switch sub.subscriptionPeriod.unit {
        case .month: return "/月"
        case .year:  return "/年"
        case .week:  return "/週"
        case .day:   return "/日"
        @unknown default: return nil
        }
    }
}
