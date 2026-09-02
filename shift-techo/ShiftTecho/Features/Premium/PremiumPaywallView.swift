import StoreKit
import SwiftUI

@MainActor
struct PremiumPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    let entitlements: StoreKitEntitlementProvider
    @State private var purchasingID: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(ShiftTechoTheme.accent)
                        .accessibilityHidden(true)
                    VStack(spacing: 8) {
                        Text("シフト手帳プレミアム").font(.title2.bold())
                        Text("もっと便利に。広告なしで、シフト管理をすっきり。")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 14) {
                        benefit("広告を非表示", icon: "rectangle.slash")
                        benefit("シフトテンプレートを無制限に作成", icon: "square.stack.3d.up")
                        benefit("今後追加される給与詳細・共有テーマ", icon: "chart.line.uptrend.xyaxis")
                        benefit("将来の iCloud 同期・ウィジェット", icon: "icloud")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if entitlements.isLoading && entitlements.products.isEmpty {
                        ProgressView("商品情報を読み込み中…")
                    } else if entitlements.products.isEmpty {
                        ContentUnavailableView(
                            "商品情報を取得できません",
                            systemImage: "wifi.exclamationmark",
                            description: Text("通信環境を確認して、もう一度お試しください。")
                        )
                        Button("再読み込み") { Task { await entitlements.prepare() } }
                            .buttonStyle(.borderedProminent)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(entitlements.products, id: \.id) { product in
                                productButton(product)
                            }
                        }
                    }

                    if let message = entitlements.errorMessage {
                        Text(message).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
                    }
                    Button("購入を復元") { Task { await entitlements.restore() } }
                        .disabled(purchasingID != nil)
                    Text("サブスクリプションは期間終了の24時間前までにキャンセルしない限り自動更新されます。購入の確定前に、App Store に表示される価格と無料トライアル条件をご確認ください。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
            }
            .navigationTitle("プレミアム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("閉じる") { dismiss() } }
            }
            .task { if entitlements.products.isEmpty { await entitlements.prepare() } }
            .onChange(of: entitlements.isPro) { _, isPro in if isPro { dismiss() } }
        }
    }

    private func benefit(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon).font(.body.weight(.medium))
    }

    private func productButton(_ product: Product) -> some View {
        Button {
            purchasingID = product.id
            Task {
                _ = await entitlements.purchase(product)
                purchasingID = nil
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.displayName).font(.headline)
                    if product.id == StoreKitEntitlementProvider.ProductID.yearly {
                        Text("おすすめ").font(.caption.bold()).foregroundStyle(ShiftTechoTheme.accent)
                    }
                }
                Spacer()
                if purchasingID == product.id { ProgressView() }
                else { Text(product.displayPrice).font(.headline) }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.borderedProminent)
        .tint(product.id == StoreKitEntitlementProvider.ProductID.yearly ? ShiftTechoTheme.accent : .secondary)
        .disabled(purchasingID != nil)
    }
}
