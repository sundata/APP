import SwiftUI
import SwimFinderCore

struct PlayerSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: SearchViewModel?

    var body: some View {
        Group {
            if let model {
                SearchForm(model: model,
                           title: "選手から探す",
                           fieldLabel: "選手名",
                           placeholder: "例：山田 花子",
                           help: "公式サイトの選手検索は今年度の登録選手が対象です。同姓同名の場合は公式ページで所属・加盟団体・学種・性別を確認して選んでください。",
                           identifierPrefix: "player")
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil { model = SearchViewModel(kind: .player, environment: environment) }
        }
    }
}

struct MeetSearchView: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var model: SearchViewModel?

    var body: some View {
        Group {
            if let model {
                SearchForm(model: model,
                           title: "大会から探す",
                           fieldLabel: "大会名",
                           placeholder: "例：日本選手権",
                           help: "公式サイトの大会検索は年度・都道府県・大会名・ステータスで絞り込めます。同名の大会は開催期間や会場で見分けてください。",
                           identifierPrefix: "meet",
                           showsYearPicker: true)
            } else {
                ProgressView()
            }
        }
        .task {
            if model == nil { model = SearchViewModel(kind: .meet, environment: environment) }
        }
    }
}

/// 選手・大会共通の検索フォーム。
struct SearchForm: View {
    @Bindable var model: SearchViewModel
    let title: String
    let fieldLabel: String
    let placeholder: String
    let help: String
    let identifierPrefix: String
    var showsYearPicker = false

    @FocusState private var isFocused: Bool

    var body: some View {
        Form {
            Section {
                TextField(fieldLabel, text: $model.rawQuery, prompt: Text(placeholder))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isFocused)
                    .onSubmit { model.openOfficialSite() }
                    .frame(minHeight: SwimFinderTheme.minimumTapSize)
                    .accessibilityLabel(fieldLabel)
                    .accessibilityIdentifier("\(identifierPrefix).queryField")
                    .onChange(of: model.rawQuery) { _, _ in model.clearMessages() }

                if showsYearPicker {
                    Picker("年度", selection: $model.fiscalYear) {
                        Text("指定しない").tag(Int?.none)
                        ForEach(model.selectableYears, id: \.self) { year in
                            Text("\(year)年度").tag(Int?.some(year))
                        }
                    }
                    .accessibilityIdentifier("\(identifierPrefix).yearPicker")
                }
            } header: {
                Text(fieldLabel)
            } footer: {
                Text(help)
            }

            Section {
                Button {
                    isFocused = false
                    model.openOfficialSite()
                } label: {
                    Label("公式サイトで検索", systemImage: "safari")
                        .frame(maxWidth: .infinity, minHeight: SwimFinderTheme.minimumTapSize)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canSubmit)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .accessibilityIdentifier("\(identifierPrefix).openOfficialSite")
                .accessibilityHint("入力した\(fieldLabel)をコピーして、公式サイトの検索ページを開きます")

                Button {
                    model.copyOnly()
                } label: {
                    Label("\(fieldLabel)をコピーする", systemImage: "doc.on.doc")
                        .frame(minHeight: SwimFinderTheme.minimumTapSize)
                }
                .disabled(!model.canSubmit)
                .accessibilityIdentifier("\(identifierPrefix).copyOnly")
            } footer: {
                Text("公式サイトは検索語の受け渡しに対応していないため、コピーした\(fieldLabel)を公式ページの入力欄に貼り付けて検索してください。検索結果はアプリに保存されません。")
            }

            if let error = model.errorMessage {
                Section {
                    NoticeBanner(kind: .warning, text: error)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("\(identifierPrefix).error")
                }
            }

            if let guidance = model.lastGuidance {
                Section {
                    NoticeBanner(kind: .info, text: guidance)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("\(identifierPrefix).guidance")
                }
            }

            Section {
                UnofficialNotice()
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
