import SwiftUI
import SwimFinderCore

struct HomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    @State private var showsPlus = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Image("BrandMark")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 46, height: 46)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("積み重ねた一秒を、次の自信へ。")
                                .font(.headline)
                                .foregroundStyle(SwimFinderTheme.navy)
                            Text("記録を探すだけでなく、成長の流れまで見渡せます。")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 5)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("home.valueMessage")
                }

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("公式情報を参照しています", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(SwimFinderTheme.officialBlue)

                        Text("選手・大会・競技結果は、公益財団法人日本水泳連盟が公開する「Results of Japan Swimming」の情報を参照しています。")
                            .font(.footnote)

                        Link(destination: OfficialSite.base) {
                            Label("公式サイトで情報を確認", systemImage: "arrow.up.right.square")
                                .font(.footnote.weight(.semibold))
                        }
                        .accessibilityIdentifier("home.officialSourceLink")

                        Text("本アプリは日本水泳連盟の公式アプリではなく、同連盟の承認・提携を受けたものではありません。情報の正確性・最新性・完全性およびサービスの継続提供を保証するものではありません。正式な記録・判断には公式発表をご確認ください。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("home.sourceDisclaimer")
                } header: {
                    Text("情報源・免責")
                }

                Section {
                    NavigationLink {
                        PlayerSearchView()
                    } label: {
                        EntryRow(title: "選手から探す", subtitle: "選手名から登録選手を検索", symbol: "person.fill")
                    }
                    .accessibilityIdentifier("home.playerSearch")

                    NavigationLink {
                        PlayerSearchView()
                    } label: {
                        EntryRow(title: "クラブ・学校から探す", subtitle: "所属名から選手と成績を検索", symbol: "building.2.fill")
                    }
                    .accessibilityIdentifier("home.affiliationSearch")

                    NavigationLink {
                        MeetSearchView()
                    } label: {
                        EntryRow(title: "大会から探す", subtitle: "大会名や年度から大会を検索", symbol: "trophy.fill")
                    }
                    .accessibilityIdentifier("home.meetSearch")
                } header: {
                    Text("検索")
                }

                if !environment.membership.isPlus {
                    Section {
                        Button { showsPlus = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "crown.fill").foregroundStyle(SwimFinderTheme.aqua)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SwimScope Plus").font(.headline)
                                    Text("通知・大会当日モード・成長分析").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("home.plus")
                    }
                }

                if !store.favorites.isEmpty {
                    Section("お気に入り") {
                        ForEach(store.favorites.prefix(3)) { link in
                            NavigationLink {
                                homeFavoriteDestination(link)
                            } label: {
                                Label(link.title, systemImage: favoriteSymbol(link))
                            }
                        }
                    }
                }

                Section {
                    if store.recentSearches.isEmpty {
                        Text("まだ検索履歴はありません")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("home.emptyRecents")
                    } else {
                        ForEach(store.recentSearches) { item in
                            NavigationLink {
                                if item.kind == .player {
                                    PlayerSearchView(initialQuery: item.normalizedQuery)
                                } else if item.kind == .affiliation {
                                    PlayerSearchView(initialAffiliation: item.normalizedQuery)
                                } else {
                                    MeetSearchView(initialQuery: item.isFilterOnly ? "" : item.normalizedQuery,
                                                   initialYear: item.fiscalYear,
                                                   initialPrefectureCode: item.prefectureCode,
                                                   initialStatusCode: item.statusCode,
                                                   initialWaterwayCode: item.waterwayCode)
                                }
                            } label: {
                                RecentSearchRow(item: item)
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

            }
            .swimFinderScreen()
            .navigationTitle("SwimScope")
            .sheet(isPresented: $showsPlus) { PlusView() }
        }
    }

    @ViewBuilder
    private func homeFavoriteDestination(_ link: FavoriteLink) -> some View {
        let parts = link.url.pathComponents.filter { $0 != "/" }
        if link.kind == .athlete, let id = parts.last {
            PlayerDetailView(player: PlayerSummary(id: id, athleteID: id, displayName: link.title))
        } else if link.kind == .tournament, let id = parts.last {
            MeetDetailView(meet: MeetSummary(id: id, name: link.title))
        } else if link.kind == .playerSearch,
                  let components = URLComponents(url: link.url, resolvingAgainstBaseURL: false),
                  let affiliation = components.queryItems?.first(where: { $0.name == "entry_group_name" })?.value {
            PlayerSearchView(initialAffiliation: affiliation)
        } else {
            PlayerSearchView()
        }
    }

    private func favoriteSymbol(_ link: FavoriteLink) -> String {
        switch link.kind {
        case .athlete, .playerSearch: return link.url.query == nil ? "person.fill" : "building.2.fill"
        case .tournament, .tournamentList: return "trophy.fill"
        case .raceResult: return "flag.checkered"
        case .other: return "star.fill"
        }
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
                Text(verbatim: subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: SwimFinderTheme.minimumTapSize)
        .accessibilityElement(children: .combine)
    }
}

private struct RecentSearchRow: View {
    let item: RecentSearch

    var body: some View {
        HStack {
            Image(systemName: icon)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.normalizedQuery).font(.body)
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(minHeight: SwimFinderTheme.minimumTapSize)
        .accessibilityLabel("\(item.kind.title)検索「\(item.normalizedQuery)」")
        .accessibilityIdentifier("recent.\(item.kind.rawValue)")
    }

    private var subtitle: String {
        var text = item.kind.title
        if let year = item.fiscalYear { text += "・\(year)年度" }
        text += "・" + item.searchedAt.formatted(date: .abbreviated, time: .shortened)
        return text
    }

    private var icon: String {
        switch item.kind {
        case .player: return "person"
        case .affiliation: return "building.2"
        case .meet: return "trophy"
        }
    }
}
