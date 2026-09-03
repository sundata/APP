import SwiftUI
import SwimFinderCore

struct PlayerSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: SearchViewModel?
    let initialQuery: String
    let initialAffiliation: String

    init(initialQuery: String = "", initialAffiliation: String = "") {
        self.initialQuery = initialQuery
        self.initialAffiliation = initialAffiliation
    }

    var body: some View {
        Group {
            if let model {
                SearchForm(model: model,
                           title: "選手・所属から探す",
                           fieldLabel: "選手名",
                           placeholder: "例：山田 花子",
                           help: "選手名、クラブ・学校などの所属名、または両方を入力して検索できます。検索対象は今年度の登録選手です。",
                           identifierPrefix: "player",
                           showsAffiliationField: true)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                let newModel = SearchViewModel(kind: .player, environment: environment)
                newModel.rawQuery = initialQuery
                newModel.affiliationQuery = initialAffiliation
                model = newModel
            }
        }
    }
}

struct MeetSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: SearchViewModel?
    let initialQuery: String
    let initialYear: Int?
    let initialPrefectureCode: Int?
    let initialStatusCode: Int?
    let initialWaterwayCode: Int?

    init(initialQuery: String = "", initialYear: Int? = nil, initialPrefectureCode: Int? = nil, initialStatusCode: Int? = nil, initialWaterwayCode: Int? = nil) {
        self.initialQuery = initialQuery
        self.initialYear = initialYear
        self.initialPrefectureCode = initialPrefectureCode
        self.initialStatusCode = initialStatusCode
        self.initialWaterwayCode = initialWaterwayCode
    }

    var body: some View {
        Group {
            if let model {
                SearchForm(model: model,
                           title: "大会から探す",
                           fieldLabel: "大会名",
                           placeholder: "例：日本選手権",
                           help: "公式サイトの大会検索は年度・都道府県・大会名・ステータスで絞り込めます。同名の大会は開催期間や会場で見分けてください。",
                           identifierPrefix: "meet",
                           showsYearPicker: true,
                           showsMeetFilters: true)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil {
                let newModel = SearchViewModel(kind: .meet, environment: environment)
                newModel.rawQuery = initialQuery
                newModel.fiscalYear = initialYear
                newModel.prefectureCode = initialPrefectureCode
                newModel.statusCode = initialStatusCode
                newModel.waterwayCode = initialWaterwayCode
                model = newModel
            }
        }
    }
}

/// 選手・大会共通の検索フォーム。
struct SearchForm: View {
    @Environment(LocalStore.self) private var store
    @Bindable var model: SearchViewModel
    let title: String
    let fieldLabel: String
    let placeholder: String
    let help: String
    let identifierPrefix: String
    var showsYearPicker = false
    var showsAffiliationField = false
    var showsMeetFilters = false

    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField(fieldLabel, text: $model.rawQuery, prompt: Text(placeholder))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { Task { await model.search() } }
                    .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    .accessibilityLabel(fieldLabel)
                    .accessibilityIdentifier("\(identifierPrefix).queryField")
                    .onChange(of: model.rawQuery) { _, _ in model.clearMessages() }

                if showsAffiliationField {
                    TextField("所属名", text: $model.affiliationQuery, prompt: Text("例：○○スイミング、○○高校"))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.search)
                        .onSubmit { Task { await model.search() } }
                        .frame(minHeight: SwimFinderTheme.minimumTapSize)
                        .accessibilityLabel("所属名（クラブ・学校）")
                        .accessibilityIdentifier("player.affiliationField")
                        .onChange(of: model.affiliationQuery) { _, _ in model.clearMessages() }
                }

                if showsYearPicker {
                    Picker("年度", selection: $model.fiscalYear) {
                        Text("指定しない").tag(Int?.none)
                        ForEach(model.selectableYears, id: \.self) { year in
                            // LocalizedStringKey 会把年份当作数字并自动加入千位分隔符。
                            Text(verbatim: "\(year)年度").tag(Int?.some(year))
                        }
                    }
                    .accessibilityIdentifier("\(identifierPrefix).yearPicker")
                }

                if showsMeetFilters {
                    Picker("都道府県", selection: $model.prefectureCode) {
                        Text("指定しない").tag(Int?.none)
                        ForEach(SearchViewModel.prefectures, id: \.code) { item in
                            Text(item.name).tag(Int?.some(item.code))
                        }
                    }
                    .accessibilityIdentifier("meet.prefecturePicker")

                    Picker("開催状況", selection: $model.statusCode) {
                        Text("指定しない").tag(Int?.none)
                        ForEach(SearchViewModel.statuses, id: \.code) { item in
                            Text(item.name).tag(Int?.some(item.code))
                        }
                    }
                    .accessibilityIdentifier("meet.statusPicker")

                    Picker("水路", selection: $model.waterwayCode) {
                        Text("指定しない").tag(Int?.none)
                        Text("長水路").tag(Int?.some(1))
                        Text("短水路").tag(Int?.some(2))
                    }
                    .accessibilityIdentifier("meet.waterwayPicker")
                }
            } header: {
                Text(fieldLabel)
            } footer: {
                Text(help)
            }
            Section {
                Button {
                    isFocused = false
                    Task { await model.search() }
                } label: {
                    if model.isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: SwimFinderTheme.minimumTapSize)
                    } else {
                        Label("検索", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, minHeight: SwimFinderTheme.minimumTapSize)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSubmit || model.isLoading)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("\(identifierPrefix).search")
            }

            if let error = model.errorMessage {
                Section {
                    NoticeBanner(kind: .warning, text: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("\(identifierPrefix).error")
                }
            }

            if !model.players.isEmpty {
                Section {
                    ForEach(model.players) { player in
                        NavigationLink {
                            PlayerDetailView(player: player)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(player.displayName).font(.headline)
                                if let affiliation = player.affiliation { Text(affiliation).font(.subheadline) }
                                Text([player.memberGroup, player.schoolClass, player.gender].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: { Text("検索結果（\(model.players.count)件）") }
            } else if !model.meets.isEmpty {
                Section {
                    ForEach(model.meets) { meet in
                        NavigationLink {
                            MeetDetailView(meet: meet)
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(meet.name).font(.headline)
                                if let period = meet.period { Label(period, systemImage: "calendar").font(.subheadline) }
                                if let venue = meet.venue { Label(venue, systemImage: "mappin.and.ellipse").font(.subheadline) }
                                Text([meet.organizer, meet.course, meet.status].compactMap { $0 }.joined(separator: " · "))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: { Text("検索結果（\(model.meets.count)件）") }
            } else if model.hasSearched && model.errorMessage == nil && !model.isLoading {
                Section {
                    ContentUnavailableView.search(text: model.normalizedQuery)
                }
            }
        }
        .swimFinderScreen()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsAffiliationField,
               QueryNormalizer.isSearchable(model.affiliationQuery),
               let url = OfficialSite.affiliationSearch(name: model.affiliationQuery) {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if store.isFavorite(url) { store.removeFavorite(url: url) }
                        else { store.addFavorite(title: QueryNormalizer.normalize(model.affiliationQuery), url: url) }
                    } label: {
                        Label("所属をお気に入り", systemImage: store.isFavorite(url) ? "star.fill" : "star")
                    }
                    .accessibilityIdentifier("player.favoriteAffiliation")
                }
            }
        }
    }
}
