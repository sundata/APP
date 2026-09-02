import SwiftUI
import SwimFinderCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    @State private var confirmClearHistory = false
    @State private var confirmClearFavorites = false

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(role: .destructive) {
                        confirmClearHistory = true
                    } label: {
                        Label("検索履歴をすべて削除", systemImage: "trash")
                            .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    }
                    .disabled(store.recentSearches.isEmpty)
                    .accessibilityIdentifier("settings.clearHistory")
                    .confirmationDialog("検索履歴をすべて削除しますか？", isPresented: $confirmClearHistory, titleVisibility: .visible) {
                        Button("削除", role: .destructive) { store.clearRecents() }
                            .accessibilityIdentifier("settings.clearHistory.confirm")
                    } message: {
                        Text("この操作は取り消せません。履歴は端末内にのみ保存されています。")
                    }

                    Button(role: .destructive) {
                        confirmClearFavorites = true
                    } label: {
                        Label("お気に入りをすべて削除", systemImage: "star.slash")
                            .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    }
                    .disabled(store.favorites.isEmpty)
                    .accessibilityIdentifier("settings.clearFavorites")
                    .confirmationDialog("お気に入りをすべて削除しますか？", isPresented: $confirmClearFavorites, titleVisibility: .visible) {
                        Button("削除", role: .destructive) { store.clearFavorites() }
                    }
                } header: {
                    Text("データ")
                } footer: {
                    Text("検索履歴 \(store.recentSearches.count) 件、お気に入り \(store.favorites.count) 件")
                }

                Section {
                    NavigationLink("情報源とこのアプリについて") { AboutView() }
                        .accessibilityIdentifier("settings.about")
                    NavigationLink("プライバシーポリシー") { PrivacyPolicyView() }
                        .accessibilityIdentifier("settings.privacy")
                    NavigationLink("できること・できないこと") { LimitationsView() }
                        .accessibilityIdentifier("settings.limitations")
                } header: {
                    Text("情報")
                }

                Section {
                    Button {
                        environment.browser.open(url: OfficialSite.base)
                    } label: {
                        Label("公式結果サイトを開く", systemImage: "safari")
                            .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    }
                    LabeledContent("バージョン", value: appVersion)
                } header: {
                    Text("その他")
                }
            }
            .navigationTitle("設定")
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UnofficialNotice()

                InfoBlock(title: "情報源") {
                    Text("競泳の結果は、公益財団法人日本水泳連盟が運営する公式結果サイト「Results of Japan Swimming」（https://result.swim.or.jp/）に掲載されています。本アプリはその公式ページを Safari 表示で開くための入口です。")
                }
                InfoBlock(title: "免責") {
                    Text("結果の正確性・最新性は公式サイトの掲載内容に基づきます。本アプリは結果本文を取得・保存・改変せず、常に公式ページの最新表示を確認できるようにしています。表示内容に疑問がある場合は必ず公式ページでご確認ください。")
                }
                InfoBlock(title: "商標・著作権") {
                    Text("公式サイトおよびその掲載内容の権利は日本水泳連盟および各権利者に帰属します。本アプリは日本水泳連盟の承認・提携を受けたものではありません。")
                }
                InfoBlock(title: "お問い合わせ") {
                    Text("本アプリに関するお問い合わせは App Store のサポート URL からお願いします。公式結果の内容に関するお問い合わせは、公式サイトの案内に従ってください。")
                }
            }
            .padding()
        }
        .navigationTitle("情報源とこのアプリについて")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LimitationsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoBlock(title: "できること") {
                    BulletList([
                        "選手名・大会名を入力して、公式サイトの検索ページをすぐに開く",
                        "入力した検索語をコピーして、公式ページの入力欄に貼り付ける",
                        "検索条件を端末内に履歴として残す（最大\(SearchHistoryPolicy.maxCount)件）",
                        "公式サイトのページ URL をお気に入りとして保存する",
                    ])
                }
                InfoBlock(title: "できないこと（現在の仕様）") {
                    BulletList([
                        "アプリ内で結果一覧やタイムを直接表示すること",
                        "検索語を公式サイトへ自動入力すること（公式サイトが対応していないため）",
                        "同姓同名の選手や同名の大会を自動で確定すること",
                        "公式サイトに掲載されていない結果を推測・補完すること",
                    ])
                }
                InfoBlock(title: "理由") {
                    Text("公式サイトのデータ利用について正式な許諾が確認できるまで、アプリは公式ページを開くだけの方式（公式サイト遷移モード）で提供しています。公式サイトへの自動アクセスや結果の複製は行いません。")
                }
            }
            .padding()
        }
        .navigationTitle("できること・できないこと")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InfoBlock(title: "収集する情報") {
                    Text("本アプリは、氏名・生年月日・住所・連絡先などの個人情報を収集しません。アカウント登録も不要です。")
                }
                InfoBlock(title: "端末内に保存する情報") {
                    BulletList([
                        "入力した検索語（選手名・大会名）と年度、公式検索ページの URL、検索日時（最大\(SearchHistoryPolicy.maxCount)件）",
                        "お気に入りとして保存した公式ページの URL と名前",
                    ])
                    Text("これらは端末内にのみ保存され、外部サーバーへ送信されません。設定画面からいつでも削除できます。")
                }
                InfoBlock(title: "外部送信") {
                    Text("本アプリは分析 SDK や広告 SDK を含まず、検索語や利用状況を外部へ送信しません。公式サイトの表示は Safari 表示（SFSafariViewController）で行われ、その通信は公式サイトのプライバシーポリシーに従います。")
                }
                InfoBlock(title: "クリップボード") {
                    Text("「公式サイトで検索」または「コピーする」を押したときだけ、入力した検索語をクリップボードへコピーします。クリップボードの読み取りは行いません。")
                }
                InfoBlock(title: "改定") {
                    Text("本ポリシーを変更する場合は、アプリのアップデートおよび App Store のページでお知らせします。")
                }
            }
            .padding()
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct InfoBlock<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content.font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

private struct BulletList: View {
    let items: [String]
    init(_ items: [String]) { self.items = items }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("・").accessibilityHidden(true)
                    Text(item)
                }
            }
        }
    }
}
