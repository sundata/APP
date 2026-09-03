import SwiftUI
import SwimFinderCore

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.favorites.isEmpty {
                        ContentUnavailableView("お気に入りはまだありません", systemImage: "star", description: Text("選手・所属・大会の詳細画面にある星ボタンから追加できます。"))
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("favorites.empty")
                    } else {
                        ForEach(store.favorites) { link in
                            NavigationLink {
                                favoriteDestination(link)
                            } label: {
                                FavoriteRow(link: link)
                            }
                            .accessibilityLabel("お気に入り「\(link.title)」を開く")
                            .accessibilityIdentifier("favorite.row")
                        }
                        .onDelete { offsets in
                            let targets = offsets.map { store.favorites[$0] }
                            for link in targets {
                                store.removeFavorite(link).forEach { environment.resultUpdateMonitor.cancelRaceReminder(id: $0) }
                            }
                            syncWatchedAthletes()
                        }
                    }
                } footer: {
                    Text("お気に入りはこの端末内にのみ保存されます。")
                }

            }
            .swimFinderScreen()
            .navigationTitle("お気に入り")
        }
    }

    private func syncWatchedAthletes() {
        let athletes = store.favorites.filter { $0.kind == .athlete }.compactMap { link -> (id: String, name: String)? in
            guard let id = link.url.pathComponents.filter({ $0 != "/" }).last else { return nil }
            return (id, link.title)
        }
        environment.resultUpdateMonitor.syncWatchedAthletes(athletes)
    }

    @ViewBuilder
    private func favoriteDestination(_ link: FavoriteLink) -> some View {
        let parts = link.url.pathComponents.filter { $0 != "/" }
        if link.kind == .athlete, let id = parts.last {
            PlayerDetailView(player: PlayerSummary(id: id, athleteID: id, displayName: link.title))
        } else if link.kind == .tournament, let id = parts.last {
            MeetDetailView(meet: MeetSummary(id: id, name: link.title))
        } else if link.kind == .playerSearch,
                  let components = URLComponents(url: link.url, resolvingAgainstBaseURL: false),
                  let affiliation = components.queryItems?.first(where: { $0.name == "entry_group_name" })?.value {
            PlayerSearchView(initialAffiliation: affiliation)
        } else if link.kind == .playerSearch {
            PlayerSearchView()
        } else {
            MeetSearchView()
        }
    }
}

private struct FavoriteRow: View {
    let link: FavoriteLink

    var body: some View {
        HStack {
            Image(systemName: symbol).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.title).font(.body)
                Text(kindLabel).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .frame(minHeight: SwimFinderTheme.minimumTapSize)
    }

    private var symbol: String {
        switch link.kind {
        case .athlete, .playerSearch: return "person"
        case .tournament, .tournamentList: return "trophy"
        case .raceResult: return "flag.checkered"
        case .other: return "link"
        }
    }

    private var kindLabel: String {
        switch link.kind {
        case .athlete: return "選手"
        case .playerSearch: return link.url.query == nil ? "選手検索" : "クラブ・学校"
        case .tournament: return "大会"
        case .tournamentList: return "大会検索"
        case .raceResult: return "競技結果"
        case .other: return "お気に入り"
        }
    }
}

/// 公式サイトの URL を貼り付けてお気に入りに登録する。公式サイト以外の URL は拒否する。
struct AddFavoriteView: View {
    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var urlText = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("名前", text: $title, prompt: Text("例：〇〇選手 / 〇〇大会"))
                        .frame(minHeight: SwimFinderTheme.minimumTapSize)
                        .accessibilityIdentifier("addFavorite.title")
                    TextField("公式ページの URL", text: $urlText, prompt: Text("https://result.swim.or.jp/..."))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: SwimFinderTheme.minimumTapSize)
                        .accessibilityIdentifier("addFavorite.url")
                } footer: {
                    Text("公式サイト（result.swim.or.jp）の URL だけ保存できます。Safari の共有メニューから URL をコピーして貼り付けてください。")
                }
                if let errorMessage {
                    Section {
                        NoticeBanner(kind: .warning, text: errorMessage)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .accessibilityIdentifier("addFavorite.error")
                    }
                }
            }
            .swimFinderScreen()
            .navigationTitle("お気に入りを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .accessibilityIdentifier("addFavorite.save")
                }
            }
        }
    }

    private func save() {
        let trimmed = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), OfficialSite.isOfficialURL(url) else {
            errorMessage = "公式サイト（https://result.swim.or.jp/）の URL を入力してください。"
            return
        }
        guard !store.isFavorite(url) else {
            errorMessage = "この URL はすでにお気に入りに登録されています。"
            return
        }
        if store.addFavorite(title: title, url: url) {
            dismiss()
        } else {
            errorMessage = store.lastError ?? "保存できませんでした。"
        }
    }
}
