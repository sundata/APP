import Foundation
import Combine

// MARK: - サブスクリプション管理
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var subscription: UserSubscription = UserSubscription()
    @Published var showSubscriptionPrompt = false
    @Published var promptReason: String = ""  // "limit" または "pro"
    
    private init() {
        loadSubscription()
        resetDailyUsageIfNeeded()
    }
    
    // MARK: - AI分析前のチェック
    func checkCanUseAIAnalysis() -> Bool {
        resetDailyUsageIfNeeded()
        
        if subscription.canUseAIAnalysis {
            return true
        }
        
        // 4回目のAI利用時：課金トリガーパターン1
        showSubscriptionPrompt = true
        promptReason = "limit"
        return false
    }
    
    // MARK: - 深度分析前のチェック
    func checkCanUseDeepAnalysis() -> Bool {
        if !subscription.isPro {
            // 深度分析クリック時：課金トリガーパターン2
            showSubscriptionPrompt = true
            promptReason = "pro"
            return false
        }
        return true
    }
    
    // MARK: - AI分析の使用を記録
    func recordAIAnalysisUsage() {
        subscription.incrementAIAnalysisUsage()
        saveSubscription()
    }
    
    // MARK: - Pro登録（実装例：アプリ内課金連携）
    func upgradeToPro(expiryDate: Date) {
        subscription.plan = .pro
        subscription.proExpiryDate = expiryDate
        saveSubscription()
    }
    
    // MARK: - Pro解除
    func downgradeToPlan() {
        subscription.plan = .free
        subscription.proExpiryDate = nil
        saveSubscription()
    }
    
    // MARK: - 日次リセット
    private func resetDailyUsageIfNeeded() {
        subscription.resetDailyUsage()
        saveSubscription()
    }
    
    // MARK: - ローカル保存
    private func saveSubscription() {
        if let encoded = try? JSONEncoder().encode(subscription) {
            UserDefaults.standard.set(encoded, forKey: "UserSubscription")
        }
    }
    
    private func loadSubscription() {
        if let data = UserDefaults.standard.data(forKey: "UserSubscription"),
           let decoded = try? JSONDecoder().decode(UserSubscription.self, from: data) {
            self.subscription = decoded
        }
    }
    
    // MARK: - デバッグ用
    func resetToFree() {
        downgradeToPlan()
        subscription.aiAnalysisUsedToday = 0
        saveSubscription()
    }
    
    func setProForDebug() {
        let expiryDate = Calendar.current.date(byAdding: .day, value: 365, to: Date()) ?? Date()
        upgradeToPro(expiryDate: expiryDate)
    }
}