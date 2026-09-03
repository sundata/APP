import StoreKit
import SwiftUI

struct PlusView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private var membership: MembershipStore { environment.membership }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    Image("BrandMark")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: SwimFinderTheme.navy.opacity(0.18), radius: 12, y: 6)
                        .accessibilityHidden(true)
                    VStack(spacing: 7) {
                        Text("SwimScope Plus").font(.largeTitle.bold())
                        Text("公式記録を見るだけでなく、成長を見守り、レース当日を支えるための機能です。")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 15) {
                        benefit("bell.badge.fill", "成績更新とレース前の通知")
                        benefit("person.3.fill", "3名以上の選手・家族・チーム管理")
                        benefit("chart.xyaxis.line", "詳細な推移、目標、成長の振り返り")
                        benefit("rectangle.on.rectangle.angled", "プライバシーに配慮した共有カード")
                    }
                    .padding().background(.regularMaterial, in: RoundedRectangle(cornerRadius: 22))

                    if membership.isPlus {
                        Label("Plus会員です", systemImage: "checkmark.seal.fill")
                            .font(.headline).foregroundStyle(SwimFinderTheme.success)
                            .accessibilityIdentifier("plus.active")
                    } else if membership.isLoading {
                        ProgressView("会員情報を確認中…")
                    } else if membership.products.isEmpty {
                        NoticeBanner(kind: .info, text: "購入商品の準備中です。検索と公式成績の閲覧は無料で利用できます。")
                    } else {
                        ForEach(membership.products, id: \.id) { product in
                            Button { Task { await membership.purchase(product) } } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(product.displayName).font(.headline)
                                        Text(product.description).font(.caption).opacity(0.85)
                                    }
                                    Spacer()
                                    Text(product.displayPrice).font(.headline)
                                }
                                .padding().frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("plus.purchase")
                        }
                    }

                    Button("購入を復元") { Task { await membership.restore() } }
                        .disabled(membership.isLoading)
                        .accessibilityIdentifier("plus.restore")
                    HStack(spacing: 18) {
                        NavigationLink("プライバシーポリシー") { PrivacyPolicyView() }
                        Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    }
                    .font(.footnote)
                    Text("お支払いはApple IDに請求され、自動更新はApple IDのサブスクリプション設定からいつでも停止できます。無料の検索・公式成績閲覧は継続して利用できます。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
            }
            .swimFinderScreen()
            .navigationTitle("Plus会員")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
            .task { if membership.products.isEmpty { await membership.load() } }
            .alert("お知らせ", isPresented: Binding(get: { membership.errorMessage != nil }, set: { if !$0 { membership.clearError() } })) {
                Button("OK") { membership.clearError() }
            } message: { Text(membership.errorMessage ?? "") }
        }
    }

    private func benefit(_ symbol: String, _ text: String) -> some View {
        Label(text, systemImage: symbol).font(.headline).foregroundStyle(SwimFinderTheme.navy)
    }
}
