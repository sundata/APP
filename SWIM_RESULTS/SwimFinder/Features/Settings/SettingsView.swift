import SwiftUI
import UserNotifications
import SwimFinderCore

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    @State private var confirmClearHistory = false
    @State private var confirmClearAllData = false
    @State private var notificationsEnabled = false
    @State private var notificationStatus = "確認中"
    @State private var checkingResults = false
    @State private var lastCheckedAt: Date?
    @State private var showsPlus = false

    private var appVersion: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showsPlus = true } label: {
                        HStack {
                            Label("SwimScope Plus", systemImage: "crown.fill")
                            Spacer()
                            Text(environment.membership.isPlus ? "会員" : "詳しく見る")
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .accessibilityIdentifier("settings.plus")
                } footer: {
                    Text("選手・大会の検索と公式成績の閲覧は、会員登録なしで利用できます。")
                }

                Section {
                    if environment.membership.isPlus {
                        Toggle(isOn: $notificationsEnabled) {
                            Label("成績更新を通知", systemImage: "bell.badge")
                        }
                        .accessibilityIdentifier("settings.notifications")
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    let granted = await environment.resultUpdateMonitor.requestAuthorization()
                                    if !granted { notificationsEnabled = false }
                                    await refreshNotificationState()
                                }
                            } else {
                                environment.resultUpdateMonitor.isEnabled = false
                            }
                        }
                    } else {
                        Button { showsPlus = true } label: {
                            Label("成績更新通知をPlusで利用", systemImage: "lock.fill")
                        }
                        .accessibilityIdentifier("settings.notifications.locked")
                    }
                    LabeledContent("通知権限", value: notificationStatus)
                    if let lastCheckedAt {
                        LabeledContent("最終確認") { Text(lastCheckedAt, format: .dateTime.month().day().hour().minute()) }
                    }
                    Button {
                        Task { await checkNow() }
                    } label: {
                        if checkingResults { ProgressView().frame(maxWidth: .infinity) }
                        else { Label("今すぐ成績を確認", systemImage: "arrow.clockwise").frame(maxWidth: .infinity) }
                    }
                    .disabled(!notificationsEnabled || checkingResults || watchedAthletes.isEmpty)
                    .accessibilityIdentifier("settings.checkResultsNow")
                } header: { Text("通知") } footer: {
                    Text("App 起動時・手動更新時に加え、iOS が許可したタイミングでバックグラウンド確認します。実行時刻はシステムが決めるため、リアルタイム通知ではありません。")
                }

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
                        confirmClearAllData = true
                    } label: {
                        Label("端末内データをすべて削除", systemImage: "externaldrive.badge.xmark")
                            .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    }
                    .accessibilityIdentifier("settings.clearAllData")
                    .confirmationDialog("端末内データをすべて削除しますか？", isPresented: $confirmClearAllData, titleVisibility: .visible) {
                        Button("すべて削除", role: .destructive) {
                            store.clearAllLocalData()
                            environment.resultUpdateMonitor.clearLocalState()
                            lastCheckedAt = nil
                        }
                        .accessibilityIdentifier("settings.clearAllData.confirm")
                    } message: {
                        Text("検索履歴、お気に入り、目標タイム、当日プラン、ニックネームとグループが削除されます。この操作は取り消せません。")
                    }

                } header: {
                    Text("データ")
                } footer: {
                    Text("検索履歴 \(store.recentSearches.count) 件・お気に入り \(store.favorites.count) 件・目標 \(store.goals.count) 件")
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
                    LabeledContent("バージョン", value: appVersion)
                } header: {
                    Text("その他")
                }
            }
            .swimFinderScreen()
            .navigationTitle("設定")
            .sheet(isPresented: $showsPlus) { PlusView() }
            .onAppear {
                notificationsEnabled = environment.resultUpdateMonitor.isEnabled
                lastCheckedAt = environment.resultUpdateMonitor.lastCheckedAt
                Task { await refreshNotificationState() }
            }
        }
    }

    private var watchedAthletes: [(id: String, name: String)] {
        store.favorites.filter { $0.kind == .athlete }.compactMap { link in
            guard let id = link.url.pathComponents.filter({ $0 != "/" }).last else { return nil }
            return (id, link.title)
        }
    }

    private func checkNow() async {
        checkingResults = true
        await environment.resultUpdateMonitor.check(athletes: watchedAthletes)
        lastCheckedAt = environment.resultUpdateMonitor.lastCheckedAt
        checkingResults = false
    }

    private func refreshNotificationState() async {
        switch await environment.resultUpdateMonitor.authorizationStatus() {
        case .authorized, .provisional, .ephemeral: notificationStatus = "許可済み"
        case .denied: notificationStatus = "許可されていません"
        case .notDetermined: notificationStatus = "未設定"
        @unknown default: notificationStatus = "不明"
        }
    }
}

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                UnofficialNotice()

                InfoBlock(title: "情報源") {
                    Text("競泳の選手・大会・競技結果データは、公益財団法人日本水泳連盟が公開する Results of Japan Swimming のデータを参照しています。本アプリ内で検索から結果確認まで行えます。")
                }
                InfoBlock(title: "免責") {
                    Text("結果の正確性・最新性は情報源の掲載内容に基づきます。本アプリは取得したデータを見やすく表示しますが、公式記録そのものを変更しません。表示内容に疑問がある場合は主催者または情報源でご確認ください。")
                }
                InfoBlock(title: "商標・著作権") {
                    Text("公式サイトおよびその掲載内容の権利は日本水泳連盟および各権利者に帰属します。本アプリは日本水泳連盟の承認・提携を受けたものではありません。")
                    Link("日本水泳連盟の著作権・プライバシー方針を確認", destination: URL(string: "https://aquatics.or.jp/privacy/")!)
                        .font(.footnote.weight(.semibold))
                }
                InfoBlock(title: "データ利用について") {
                    Text("公開ページでは第三者アプリによるAPI継続利用を明示的に許諾する記載を確認できていません。正式公開・収益化の前に、データ取得頻度、再表示、通知利用について運営者へ確認してください。免責表示は利用許諾の代わりにはなりません。")
                }
                InfoBlock(title: "お問い合わせ") {
                    Text("本アプリに関するお問い合わせは App Store のサポート URL からお願いします。公式結果の内容に関するお問い合わせは、公式サイトの案内に従ってください。")
                }
            }
            .padding()
        }
        .swimFinderScreen()
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
                        "選手名から現在年度の登録選手を検索する",
                        "クラブ・学校などの所属名から選手を検索する",
                        "大会名・年度・都道府県・開催状況・水路から大会を検索する",
                        "大会の競技種目、順位、選手名、所属、タイムをアプリ内で確認する",
                        "選手成績を種目・年度で絞り込み、自己ベスト・前回差・推移を確認する",
                        "選手・所属・大会をお気に入りとして端末内に保存する",
                        "検索条件を端末内に履歴として残す（最大\(SearchHistoryPolicy.maxCount)件）",
                        "検索履歴から同じ条件を呼び出す",
                    ])
                }
                InfoBlock(title: "できないこと（現在の仕様）") {
                    BulletList([
                        "同姓同名の選手や同名の大会を自動で確定すること",
                        "情報源に掲載されていない結果を推測・補完すること",
                        "公式情報に存在しない記録を補完すること",
                    ])
                }
                InfoBlock(title: "データ更新") { Text("検索時と結果表示時に情報源へ問い合わせ、短時間は端末内にキャッシュします。一時的な通信障害は自動で再試行しますが、情報源の更新・メンテナンスにより表示できない場合があります。") }
            }
            .padding()
        }
        .swimFinderScreen()
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
                        "入力した検索語（選手名・所属名・大会名）、絞り込み条件、検索日時（最大\(SearchHistoryPolicy.maxCount)件）",
                        "お気に入りに登録した選手・所属・大会の識別情報",
                    ])
                    Text("これらは端末内にのみ保存され、外部サーバーへ送信されません。設定画面からいつでも削除できます。")
                }
                InfoBlock(title: "外部送信") {
                    Text("検索や成績更新確認を実行したとき、検索語、絞り込み条件、公式選手IDを結果データの提供元へ送信します。本アプリは分析 SDK や広告 SDK を含まず、利用状況の追跡を行いません。")
                }
                InfoBlock(title: "購入情報") {
                    Text("Plus会員の購入・復元・継続状況はAppleのStoreKitを通じて確認します。決済情報を本アプリが直接取得・保存することはありません。")
                }
                InfoBlock(title: "改定") {
                    Text("本ポリシーを変更する場合は、アプリのアップデートおよび App Store のページでお知らせします。")
                }
            }
            .padding()
        }
        .swimFinderScreen()
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
