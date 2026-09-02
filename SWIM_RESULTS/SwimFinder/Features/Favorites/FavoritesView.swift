import SwiftUI
import SwimFinderCore

struct FavoritesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if store.favorites.isEmpty {
                        Text("お気に入りはまだありません。公式サイトの選手ページや大会ページの URL を保存できます。")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("favorites.empty")
                    } else {
                        ForEach(store.favorites) { link in
                            Button {
                                environment.browser.open(url: link.url)
                            } label: {
                                FavoriteRow(link: link)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("お気に入り「\(link.title)」を公式サイトで開く")
                            .accessibilityIdentifier("favorite.row")
                        }
                        .onDelete { offsets in
                            let targets = offsets.map { store.favorites[$0] }
                            for link in targets { store.removeFavorite(link) }
                        }
                    }
                } footer: {
                    Text("保存されるのは公式サイトの URL と名前だけです。結果本文は保存されません。")
                }

                Section {
                    Button {
                        environment.browser.open(url: OfficialSite.playerSearch)
                    } label: {
                        Label("公式 選手検索", systemImage: "person.fill")
                            .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    }
                    Button {
                        environment.browser.open(url: OfficialSite.tournamentList)
                    } label: {
                        Label("公式 大会一覧", systemImage: "trophy.fill")
                            .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    }
                } header: {
                    Text("公式ページ")
                }
            }
            .navigationTitle("お気に入り")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isAdding = true
                    } label: {
                        Label("追加", systemImage: "plus")
                    }
                    .accessibilityIdentifier("favorites.add")
                }
            }
            .sheet(isPresented: $isAdding) {
                AddFavoriteView()
            }
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
                Text(link.url.absoluteString).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "arrow.up.right.square").accessibilityHidden(true)
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
