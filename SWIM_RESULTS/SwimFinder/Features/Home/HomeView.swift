import SwiftUI
import SwimFinderCore

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PlayerSearchView()
                    } label: {
                        EntryRow(title: "選手から探す", subtitle: "選手名を入力して公式の選手検索を開く", symbol: "person.fill")
                    }
                    .accessibilityIdentifier("home.playerSearch")

                    NavigationLink {
                        MeetSearchView()
                    } label: {
                        EntryRow(title: "大会から探す", subtitle: "大会名を入力して公式の大会検索を開く", symbol: "trophy.fill")
                    }
                    .accessibilityIdentifier("home.meetSearch")
                } header: {
                    Text("検索")
                }

                Section {
                    if store.recentSearches.isEmpty {
                        Text("まだ検索履歴はありません")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("home.emptyRecents")
                    } else {
                        ForEach(store.recentSearches) { item in
                            RecentSearchRow(item: item) {
                                reopen(item)
                            }
                        }
                        .onDelete { offsets in
                            let targets = offsets.map { store.recentSearches[$0] }
                            targets.forEach(store.deleteRecent)
                        }
                    }
                } header: {
                    Text("直近の検索")
                } footer: {
                    Text("履歴はこの端末内にのみ保存されます（最大\(SearchHistoryPolicy.maxCount)件）。")
                }

                Section {
                    UnofficialNotice()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    Button {
                        environment.browser.open(url: OfficialSite.base)
                    } label: {
                        Label("公式結果サイトを開く（result.swim.or.jp）", systemImage: "safari")
                    }
                    .accessibilityIdentifier("home.openOfficialSite")
                } header: {
                    Text("情報源")
                }
            }
            .navigationTitle("Swim Finder")
        }
    }

    private func reopen(_ item: RecentSearch) {
        let now = environment.clock.now()
        let result: Result<OfficialSiteLaunch.Plan, OfficialSiteLaunch.Failure>
        switch item.kind {
        case .player:
            result = OfficialSiteLaunch.player(PlayerQuery(rawName: item.rawQuery), now: now)
        case .meet:
            result = OfficialSiteLaunch.meet(MeetQuery(rawName: item.rawQuery, fiscalYear: item.fiscalYear), now: now)
        }
        guard case .success(let plan) = result else { return }
        environment.clipboard.copy(plan.clipboardText)
        if let history = plan.historyItem { store.recordSearch(history) }
        environment.browser.open(plan)
    }
}

private struct EntryRow: View {
    let title: String
    let subtitle: String
    let symbol: String

    var body: some View {
        HStack(spacing: SwimFinderTheme.spacing) {
            Image(systemName: symbol)
                .font(.title2)
                .frame(width: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: SwimFinderTheme.minimumTapSize)
        .accessibilityElement(children: .combine)
    }
}

struct RecentSearchRow: View {
    let item: RecentSearch
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: item.kind == .player ? "person" : "trophy")
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.normalizedQuery).font(.body)
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").accessibilityHidden(true)
            }
            .frame(minHeight: SwimFinderTheme.minimumTapSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.kind.title)検索「\(item.normalizedQuery)」を公式サイトで開く")
        .accessibilityIdentifier("recent.\(item.kind.rawValue)")
    }

    private var subtitle: String {
        var text = item.kind.title
        if let year = item.fiscalYear { text += "・\(year)年度" }
        text += "・" + item.searchedAt.formatted(date: .abbreviated, time: .shortened)
        return text
    }
}
