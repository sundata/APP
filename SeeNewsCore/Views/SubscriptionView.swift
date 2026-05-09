import SwiftUI

// MARK: - サブスクリプション画面
struct SubscriptionView: View {
    @ObservedObject var viewModel: NewsViewModel
    @StateObject private var purchaseManager = PurchaseManager.shared
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: SubscriptionPlan = .free
    @State private var billingCycle: BillingCycle = .monthly  // 月額/年額選択
    @State private var showPurchaseAlert = false
    @State private var purchaseSuccess = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    enum BillingCycle {
        case monthly
        case yearly
        
        var displayText: String {
            switch self {
            case .monthly:
                return "月額 ¥680"
            case .yearly:
                return "年額 ¥6,800"
            }
        }
        
        var savingsPercent: String {
            switch self {
            case .monthly:
                return ""
            case .yearly:
                return "17%お得"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // ── アラートバナー ──
                    let promptReason = SubscriptionManager.shared.promptReason
                    if !promptReason.isEmpty {
                        PromptAlertBanner(reason: promptReason)
                    }
                    
                    // ── ヘッダー ──
                    VStack(alignment: .leading, spacing: 8) {
                        Text("3秒ニュースプラン")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("ニュースではなく「理解」を提供")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                    
                    // ── プラン比較 ──
                    VStack(spacing: 12) {
                        PlanComparisonCard(
                            plan: .free,
                            isSelected: selectedPlan == .free,
                            onSelect: { selectedPlan = .free }
                        )
                        
                        PlanComparisonCard(
                            plan: .pro,
                            isSelected: selectedPlan == .pro,
                            onSelect: { selectedPlan = .pro }
                        )
                    }
                    
                    // ── Pro選択時：月額/年額の選択 ──
                    if selectedPlan == .pro {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("お支払い方法を選択")
                                .font(.headline)
                            
                            HStack(spacing: 12) {
                                // 月額
                                BillingCycleCard(
                                    title: "月額",
                                    price: "¥680",
                                    savings: "",
                                    isSelected: billingCycle == .monthly,
                                    onSelect: { billingCycle = .monthly }
                                )
                                .frame(maxWidth: .infinity)
                                
                                // 年額
                                BillingCycleCard(
                                    title: "年額",
                                    price: "¥6,800",
                                    savings: "17%\nお得",
                                    isSelected: billingCycle == .yearly,
                                    onSelect: { billingCycle = .yearly }
                                )
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    // ── 機能一覧 ──
                    FeatureComparisonTable()
                        .padding(.vertical, 16)
                    
                    // ── よくある質問 ──
                    FAQSection()
                    
                    Spacer()
                    
                    // ── CTA ──
                    if selectedPlan == .free {
                        Button(action: { dismiss() }) {
                            Text("無料プランを続ける")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    } else {
                        // StoreKit2による購入ボタン
                        if let product = billingCycle == .monthly ? 
                            purchaseManager.getMonthlyProduct() : 
                            purchaseManager.getYearlyProduct() {
                            
                            Button(action: {
                                Task {
                                    let success = await purchaseManager.purchase(product: product)
                                    if success {
                                        // ローカルのサブスクリプション状態を更新
                                        let expiryDate = Calendar.current.date(byAdding: .month, value: billingCycle == .monthly ? 1 : 12, to: Date()) ?? Date()
                                        viewModel.upgradeToPro(expiryDate: expiryDate)
                                        purchaseSuccess = true
                                    } else if let error = purchaseManager.error {
                                        errorMessage = error
                                        showError = true
                                    }
                                }
                            }) {
                                if purchaseManager.isLoading {
                                    ProgressView()
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.purple)
                                        .cornerRadius(8)
                                } else {
                                    VStack(spacing: 4) {
                                        Text("Proプランに登録")
                                            .font(.headline)
                                        Text(product.displayPrice)
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.purple)
                                    .cornerRadius(8)
                                }
                            }
                            .disabled(purchaseManager.isLoading)
                        } else if purchaseManager.isLoading {
                            // 製品情報読み込み中
                            VStack(spacing: 12) {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                Text("製品情報を読み込み中...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        } else if !purchaseManager.availableProducts.isEmpty && purchaseManager.error != nil {
                            // エラーメッセージを表示
                            VStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.red)
                                    .font(.title2)
                                Text("製品情報の取得に失敗しました")
                                    .font(.headline)
                                Text(purchaseManager.error ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(3)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        } else {
                            // 製品情報読み込み中（フォールバック）
                            ProgressView("製品情報を読み込み中...")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground))
            .navigationTitle("プランを選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("登録完了", isPresented: $purchaseSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Proプランへのアップグレードが完了しました！\n深度分析をお楽しみください。")
            }
            .alert("エラー", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
}

// MARK: - 課金トリガーアラートバナー
struct PromptAlertBanner: View {
    let reason: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: reason == "limit" ? "clock.badge.xmark" : "lock.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 4) {
                    if reason == "limit" {
                        Text("本日の無料分析は終了しました")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("明日再度利用可能です")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    } else if reason == "pro" {
                        Text("この機能はPro限定です")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Proプランでより深い分析をご利用ください")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ))
            .cornerRadius(12)
        }
        .padding()
    }
}

// MARK: - 月額/年額選択カード
struct BillingCycleCard: View {
    let title: String
    let price: String
    let savings: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.black)
                
                Text(price)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isSelected ? .purple : .black)
                
                if !savings.isEmpty {
                    Text(savings)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.purple.opacity(0.1) : Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.purple : Color(.systemGray3), lineWidth: 2)
            )
        }
    }
}

// MARK: - プラン比較カード
struct PlanComparisonCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.displayName)
                            .font(.headline)
                            .foregroundColor(isSelected ? .white : .black)
                        
                        Text(plan.price)
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(isSelected ? .white : (plan == .pro ? .purple : .black))
                    }
                    
                    Spacer()
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    } else {
                        Circle()
                            .stroke(Color(.systemGray3), lineWidth: 2)
                            .frame(width: 24, height: 24)
                    }
                }
                
                // 主な特徴
                VStack(alignment: .leading, spacing: 6) {
                    if plan == .free {
                        FeatureRow(title: "ニュース閲覧", available: true, isOnDarkBackground: isSelected)
                        FeatureRow(title: "AI分析", available: true, suffix: "1日3回", isOnDarkBackground: isSelected)
                        FeatureRow(title: "深度分析", available: false, isOnDarkBackground: isSelected)
                        FeatureRow(title: "広告", available: true, suffix: "あり", isOnDarkBackground: isSelected)
                    } else {
                        FeatureRow(title: "ニュース閲覧", available: true, isOnDarkBackground: isSelected)
                        FeatureRow(title: "AI分析", available: true, suffix: "無制限", isOnDarkBackground: isSelected)
                        FeatureRow(title: "深度分析", available: true, isOnDarkBackground: isSelected)
                        FeatureRow(title: "広告", available: false, suffix: "なし", isOnDarkBackground: isSelected)
                    }
                }
            }
            .padding()
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
    }
}

// MARK: - 機能行
struct FeatureRow: View {
    let title: String
    let available: Bool
    var suffix: String = ""
    var isOnDarkBackground: Bool = false  // 用于深色背景的文字颜色
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundColor(available ? .green : .gray)
            
            Text(title)
                .font(.caption)
                .foregroundColor(isOnDarkBackground ? .white : .black)
            
            if !suffix.isEmpty {
                Text(suffix)
                    .font(.caption2)
                    .foregroundColor(isOnDarkBackground ? .white.opacity(0.7) : .secondary)
            }
            
            Spacer()
        }
    }
}

// MARK: - 機能比較表
struct FeatureComparisonTable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("機能比較")
                .font(.headline)
                .padding(.bottom, 8)
            
            HStack {
                Text("機能")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                Text("無料")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 50, alignment: .center)
                Text("Pro")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 50, alignment: .center)
            }
            .padding(.bottom, 8)
            
            Divider()
            
            let features = [
                ("ニュース閲覧", true, true),
                ("AI分析", true, true),
                ("1日の分析回数", false, true),
                ("深度分析", false, true),
                ("広告", false, true),
                ("カスタマイズ", false, true)
            ]
            
            ForEach(features, id: \.0) { feature, freeAvail, proAvail in
                HStack {
                    Text(feature)
                        .font(.caption)
                    Spacer()
                    Image(systemName: freeAvail ? "checkmark" : "")
                        .foregroundColor(.green)
                        .frame(width: 50, alignment: .center)
                    Image(systemName: proAvail ? "checkmark" : "")
                        .foregroundColor(.green)
                        .frame(width: 50, alignment: .center)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - FAQ
struct FAQSection: View {
    @State private var expandedFAQ: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("よくある質問")
                .font(.headline)
            
            let faqs = [
                ("いつでもプランを変更できますか？", "はい、いつでも無料プランに戻せます"),
                ("自動更新はありますか？", "いいえ。月額または年額で明示的に選択します"),
                ("キャンセルした場合はどうなりますか？", "有効期限まで Proプラン機能を利用できます")
            ]
            
            ForEach(Array(faqs.enumerated()), id: \.offset) { index, faq in
                VStack(alignment: .leading, spacing: 8) {
                    Button(action: { 
                        withAnimation {
                            expandedFAQ = expandedFAQ == index ? nil : index
                        }
                    }) {
                        HStack {
                            Text(faq.0)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            Spacer()
                            Image(systemName: expandedFAQ == index ? "chevron.up" : "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    
                    if expandedFAQ == index {
                        Text(faq.1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
}
