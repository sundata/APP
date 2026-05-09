import Foundation
import StoreKit
import Combine

// MARK: - 課金管理（StoreKit2）
@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    
    @Published var availableProducts: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var error: String?
    
    private let userManager = UserManager.shared
    
    // 製品ID
    private let productIdentifiers = [
        "com.3secnews.pro.monthly",    // 月額
        "com.3secnews.pro.yearly"      // 年額
    ]
    
    private init() {
        Task {
            await setupPurchases()
        }
    }
    
    // MARK: - 初期設定
    private func setupPurchases() async {
        await MainActor.run {
            self.isLoading = true
        }
        print("🔍 setupPurchases started")
        
        do {
            // App Store から製品情報を取得
            print("📦 Requesting products for IDs: \(productIdentifiers)")
            let products = try await Product.products(for: productIdentifiers)
            print("✅ Received \(products.count) products")
            
            if products.isEmpty {
                print("⚠️ WARNING: No products returned from App Store!")
                print("   Make sure these Product IDs are configured in App Store Connect:")
                for id in productIdentifiers {
                    print("   - \(id)")
                }
            }
            
            await MainActor.run {
                self.availableProducts = products.sorted { $0.displayPrice < $1.displayPrice }
                print("💾 Stored \(self.availableProducts.count) products")
                for product in self.availableProducts {
                    print("  - \(product.id): \(product.displayPrice)")
                }
                self.isLoading = false
            }
            
            // 購入済み製品を確認
            await updatePurchasedProducts()
            
            // トランザクションリスナーを開始
            _ = Task.detached {
                await self.listenForTransactions()
            }
        } catch {
            print("❌ Error fetching products: \(error)")
            await MainActor.run {
                self.error = "製品情報の取得に失敗しました: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    // MARK: - 購入処理
    @MainActor
    func purchase(product: Product) async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // ユーザーに購入を促す
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                // レシートを検証
                let transaction = try verification.payloadValue
                
                // トランザクションを完了
                await transaction.finish()
                
                // サーバーに通知
                await notifyServerPurchase(product: product, transaction: transaction)
                
                // 購入済み製品を更新
                await updatePurchasedProducts()
                
                await MainActor.run {
                    isLoading = false
                }
                return true
                
            case .userCancelled:
                await MainActor.run {
                    error = "購入がキャンセルされました"
                    isLoading = false
                }
                return false
                
            case .pending:
                await MainActor.run {
                    error = "購入は保留中です。App Storeで確認してください"
                    isLoading = false
                }
                return false
                
            @unknown default:
                await MainActor.run {
                    error = "不明なエラーが発生しました"
                    isLoading = false
                }
                return false
            }
        } catch {
            await MainActor.run {
                self.error = "購入エラー: \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - 購入済み製品の確認
    private func updatePurchasedProducts() async {
        var purchasedIDs = Set<String>()
        
        // 全てのトランザクションをチェック
        for await result in Transaction.currentEntitlements {
            switch result {
            case .verified(let transaction):
                purchasedIDs.insert(transaction.productID)
            case .unverified:
                // 検証できなかったトランザクションはスキップ
                continue
            }
        }
        
        // MainActor上で購入済み商品IDsを更新
        let productIDs = purchasedIDs
        await MainActor.run { [weak self] in
            self?.purchasedProductIDs = productIDs
        }
    }
    
    // MARK: - トランザクションリスナー
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await handleVerifiedTransaction(transaction)
            case .unverified:
                continue
            }
        }
    }
    
    // MARK: - トランザクション処理
    private func handleVerifiedTransaction(_ transaction: Transaction) async {
        // 製品IDをチェック
        if productIdentifiers.contains(transaction.productID) {
            // レシート情報をサーバーに送信
            await verifyReceiptWithServer(transaction: transaction)
        }
        
        // トランザクションを完了
        await transaction.finish()
        
        // 購入済み製品を更新
        await updatePurchasedProducts()
    }
    
    // MARK: - サーバー検証（App Store Server API）
    private func verifyReceiptWithServer(transaction: Transaction) async {
        let baseURL = "https://newsnow-backend-327343217815.asia-northeast1.run.app/v1"
        guard let url = URL(string: "\(baseURL)/subscription/verify-receipt") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 認証ヘッダー
        let headers = userManager.getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // レシートデータ
        let receiptData = [
            "transactionID": transaction.id,
            "productID": transaction.productID,
            "originalTransactionID": transaction.originalID,
            "expirationDate": transaction.expirationDate?.timeIntervalSince1970 ?? 0,
            "purchaseDate": transaction.purchaseDate.timeIntervalSince1970
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: receiptData)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                print("✅ レシート検証完了: \(transaction.productID)")
            }
        } catch {
            print("⚠️ サーバー検証エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 購入後のサーバー通知
    private func notifyServerPurchase(product: Product, transaction: Transaction) async {
        let baseURL = "https://newsnow-backend-327343217815.asia-northeast1.run.app/v1"
        guard let url = URL(string: "\(baseURL)/subscription/purchase") else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // 認証ヘッダー
        let headers = userManager.getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // 購入情報
        let purchaseData = [
            "plan": product.id.contains("monthly") ? "monthly" : "yearly",
            "productID": product.id,
            "price": NSDecimalNumber(decimal: product.price).doubleValue,
            "currency": product.priceFormatStyle.locale.currency?.identifier ?? "JPY",
            "transactionID": transaction.id,
            "timestamp": Date().timeIntervalSince1970
        ] as [String: Any]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: purchaseData)
            request.httpBody = jsonData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse,
               httpResponse.statusCode == 200 {
                print("✅ 購入情報をサーバーに送信しました")
            }
        } catch {
            print("⚠️ 購入通知エラー: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 購入の復元
    @MainActor
    func restorePurchases() async -> Bool {
        isLoading = true
        error = nil
        
        do {
            // 全てのトランザクションをチェック
            var restored = false
            for await result in Transaction.all {
                if case .verified(let transaction) = result {
                    if productIdentifiers.contains(transaction.productID) {
                        print("✅ 復元された購入: \(transaction.productID)")
                        restored = true
                    }
                    await transaction.finish()
                }
            }
            
            await updatePurchasedProducts()
            isLoading = false
            
            if restored {
                error = nil
            } else {
                error = "復元する購入が見つかりました"
            }
            
            return restored
        } catch {
            await MainActor.run {
                self.error = "購入の復元に失敗しました: \(error.localizedDescription)"
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - サブスクリプション状態チェック
    @MainActor
    func isSubscriptionValid() async -> Bool {
        var isValid = false
        
        // 現在の有効な購入をチェック
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // 有効期限をチェック
                if let expiryDate = transaction.expirationDate,
                   expiryDate > Date() {
                    isValid = true
                    break
                }
            }
        }
        
        return isValid
    }
    
    // MARK: - 購入積み履歴を取得
    func getSubscriptionStatus() -> SubscriptionStatus {
        if purchasedProductIDs.isEmpty {
            return .notPurchased
        } else if purchasedProductIDs.contains("com.3secnews.pro.monthly") ||
                  purchasedProductIDs.contains("com.3secnews.pro.yearly") {
            return .subscribed
        } else {
            return .expired
        }
    }
    
    // MARK: - ユーティリティ
    func isPro() -> Bool {
        // Pro 製品が購入済みかチェック
        return purchasedProductIDs.contains("com.3secnews.pro.monthly") ||
               purchasedProductIDs.contains("com.3secnews.pro.yearly")
    }
    
    func getMonthlyProduct() -> Product? {
        availableProducts.first { $0.id == "com.3secnews.pro.monthly" }
    }
    
    func getYearlyProduct() -> Product? {
        availableProducts.first { $0.id == "com.3secnews.pro.yearly" }
    }
}

// MARK: - 購読ステータス列挙型
enum SubscriptionStatus {
    case notPurchased      // 購入なし
    case subscribed        // 有効期間中
    case expired           // 期限切れ
}
