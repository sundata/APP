import SwiftUI
import StoreKit

// MARK: - ペイウォール（広告削除プラン）
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var storeManager = StoreManager.shared
    @State private var isPurchasing = false
    @State private var showSuccess = false

    var body: some View {
        VStack(spacing: 0) {
            // ── ツールバー（閉じるボタン） ──
            HStack {
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(FontScaler.font(size: 22))
                }
            }
            .padding()
            
            // ── コンテンツ ──
            ScrollView {
                VStack(spacing: 28) {
                    // ── ヒーローエリア ──
                    heroSection

                    // ── メリット ──
                    benefitsSection

                    // ── プラン選択 ──
                    plansSection

                    // ── 復元 ──
                    restoreButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
        }
        .overlay {
            if showSuccess {
                successOverlay
            }
        }
        .overlay(alignment: .bottom) {
            if let error = storeManager.purchaseError {
                VStack {
                    Text(error)
                        .font(FontScaler.subheadline())
                        .foregroundColor(.red)
                        .padding(12)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .padding()
                    
                    Button(action: {
                        storeManager.purchaseError = nil
                    }) {
                        Text("閉じる")
                            .font(FontScaler.caption())
                            .foregroundColor(.red)
                    }
                }
                .transition(.move(edge: .bottom))
            }
        }
        .task {
            await storeManager.loadProducts(force: storeManager.products.isEmpty)
        }
    }

    // MARK: - ヒーロー
    private var heroSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "crown.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .padding(.top, 20)

            Text("プレミアムプラン")
                .font(FontScaler.font(size: 26, weight: .bold))

            Text("もう広告に邪魔されない")
                .font(FontScaler.headline())
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text("バナー広告なし × 全画面広告なし = 快適な読書体験")
                .font(FontScaler.subheadline())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - メリット
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenefitRow(icon: "nosign", text: "バナー広告なし")
            BenefitRow(icon: "rectangle.slash", text: "全画面広告なし")
            BenefitRow(icon: "sparkles", text: "快適な読書体験")
            BenefitRow(icon: "heart.fill", text: "開発をサポート")
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - プラン選択（シンプルな一回限りの購入）
    private var plansSection: some View {
        VStack(spacing: 12) {
            if storeManager.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("購入情報を読み込み中")
                        .font(FontScaler.caption())
                        .foregroundColor(.secondary)
                }
                .frame(height: 100)
            } else {
                // 買い切りプラン（500円）
                if let lifetimeProduct = storeManager.products.first(where: { $0.id == IAPProduct.removeAds }) {
                    PlanCard(
                        product: lifetimeProduct,
                        isLoading: isPurchasing,
                        onSelect: { await purchase(lifetimeProduct) }
                    )
                } else if storeManager.products.isEmpty {
                    productReloadView
                }
            }
        }
    }
    
    // MARK: - 商品未ロード時の再読み込み
    private var productReloadView: some View {
        VStack(spacing: 10) {
            Button {
                Task {
                    await storeManager.loadProducts(force: true)
                }
            } label: {
                PurchaseButtonLabel(title: "購入情報を再読み込み", subtitle: "広告削除プラン ¥500")
            }
            .buttonStyle(.plain)
            
            Text("購入ボタンが表示されない場合は、しばらく待ってから再読み込みしてください。")
                .font(FontScaler.caption())
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - 復元ボタン
    private var restoreButton: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 12))
                    Text("Apple公式の安全な決済")
                        .font(FontScaler.caption())
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                    Text("いつでも復元可能")
                        .font(FontScaler.caption())
                }
            }
            .foregroundColor(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                Text("購入を復元")
                    .font(FontScaler.subheadline())
                    .foregroundColor(.secondary)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - 成功オーバーレイ
    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.green)
                Text("プレミアムが有効になりました！")
                    .font(FontScaler.headline())
                    .foregroundColor(.primary)
                Text("広告なしでニュースをお楽しみください")
                    .font(FontScaler.subheadline())
                    .foregroundColor(.secondary)
                Button {
                    dismiss()
                } label: {
                    Text("はじめる")
                        .font(FontScaler.font(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 48)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - 購入
    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        let success = await storeManager.purchase(product)
        if success {
            showSuccess = true
        }
    }
}

// MARK: - メリット行
struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(FontScaler.font(size: 18))
                .foregroundColor(.red)
                .frame(width: 28)
            Text(text)
                .font(FontScaler.font(size: 15))
            Spacer()
        }
    }
}

// MARK: - プランカード（StoreKit Product）
struct PlanCard: View {
    let product: Product
    let isLoading: Bool
    let onSelect: () async -> Void

    var body: some View {
        Button {
            Task { await onSelect() }
        } label: {
            ZStack {
                PurchaseButtonLabel(title: "¥500で広告を削除", subtitle: "一度の購入で永久に広告なし")
                
                if isLoading {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.3))
                    ProgressView()
                        .tint(.white)
                }
            }
        }
        .disabled(isLoading)
        .buttonStyle(.plain)
    }
}

private struct PurchaseButtonLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "nosign")
                    .font(FontScaler.font(size: 17, weight: .bold))
                Text(title)
                    .font(FontScaler.font(size: 18, weight: .bold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(FontScaler.font(size: 13, weight: .bold))
            }
            Text(subtitle)
                .font(FontScaler.caption())
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundColor(.white.opacity(0.88))
        }
        .foregroundColor(.white)
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.red.opacity(0.24), radius: 12, x: 0, y: 6)
    }
}

// MARK: - フォールバックプランカード（商品未ロード時）
struct FallbackPlanCard: View {
    let title: String
    let price: String
    let subtitle: String?
    let badge: String?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(FontScaler.font(size: 16, weight: .semibold))
                        if let badge = badge {
                            Text(badge)
                                .font(FontScaler.font(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(FontScaler.caption())
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Text(price)
                    .font(FontScaler.font(size: 18, weight: .bold))
            }
            .padding(16)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
