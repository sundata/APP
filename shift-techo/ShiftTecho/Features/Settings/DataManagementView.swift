import SwiftUI
import UniformTypeIdentifiers
import ShiftTechoCore

/// JSON バックアップの書き出し・読み込みと、すべてのデータの削除。
@MainActor
struct DataManagementView: View {
    private let environment: AppEnvironment
    private let onResetToOnboarding: () -> Void

    @State private var exportedURL: URL?
    @State private var showsImporter = false
    @State private var pendingImport: BackupDocument?
    @State private var showsReplaceConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var showsDeleteSecondConfirmation = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    init(environment: AppEnvironment, onResetToOnboarding: @escaping () -> Void) {
        self.environment = environment
        self.onResetToOnboarding = onResetToOnboarding
    }

    private var store: ShiftTechoStore { environment.store }

    var body: some View {
        Form {
            Section {
                Button("バックアップを書き出す") { export() }
                    .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
                    .accessibilityIdentifier("exportBackupButton")
                if let exportedURL {
                    ShareLink(item: exportedURL) {
                        Text("書き出したファイルを共有")
                            .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
                    }
                    .accessibilityIdentifier("shareBackupButton")
                }
            } header: {
                Text("書き出し")
            } footer: {
                Text("ファイルにはシフト・メモ・給与設定が含まれます。保管と共有にはご注意ください。")
            }

            Section {
                Button("バックアップを読み込む") { showsImporter = true }
                    .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
                    .accessibilityIdentifier("importBackupButton")
            } header: {
                Text("読み込み")
            } footer: {
                Text("読み込み前に「追加」か「置き換え」を選べます。読み込みに失敗した場合、現在のデータは変更されません。")
            }

            Section {
                Button("すべてのデータを削除", role: .destructive) { showsDeleteConfirmation = true }
                    .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
                    .accessibilityIdentifier("deleteAllDataButton")
            } header: {
                Text("削除")
            } footer: {
                Text("シフト・テンプレート・設定をすべて消し、初回起動の状態に戻します。")
            }

            if let infoMessage {
                Section {
                    Text(infoMessage)
                        .font(ShiftTechoTheme.captionFont)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("dataInfoMessage")
                }
            }
        }
        .navigationTitle("バックアップと削除")
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.json]) { result in
            handleImportSelection(result)
        }
        .confirmationDialog(
            "読み込み方法を選んでください",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            titleVisibility: .visible
        ) {
            Button("いまのデータに追加する") { performImport(strategy: .merge) }
                .accessibilityIdentifier("importMergeButton")
            Button("すべて置き換える", role: .destructive) { showsReplaceConfirmation = true }
                .accessibilityIdentifier("importReplaceButton")
            Button("キャンセル", role: .cancel) { pendingImport = nil }
        }
        .alert("いまのデータを消して置き換えます", isPresented: $showsReplaceConfirmation) {
            Button("置き換える", role: .destructive) { performImport(strategy: .replace) }
            Button("キャンセル", role: .cancel) { pendingImport = nil }
        } message: {
            Text("この操作は取り消せません。")
        }
        .alert("すべてのデータを削除しますか？", isPresented: $showsDeleteConfirmation) {
            Button("次へ", role: .destructive) { showsDeleteSecondConfirmation = true }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("シフト・テンプレート・設定がすべて消えます。")
        }
        .alert("本当に削除しますか？", isPresented: $showsDeleteSecondConfirmation) {
            Button("削除する", role: .destructive) { deleteAll() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("この操作は取り消せません。")
        }
        .alert("うまくいきませんでした", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func export() {
        do {
            let url = try environment.backupProvider.write(store.backupDocument())
            exportedURL = url
            infoMessage = "書き出しました：\(url.lastPathComponent)"
        } catch {
            errorMessage = "バックアップを書き出せませんでした。空き容量を確認してもう一度お試しください。"
        }
    }

    private func handleImportSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                pendingImport = try environment.backupProvider.read(from: url)
            } catch BackupError.unsupportedSchemaVersion(let version) {
                errorMessage = "このファイルの形式（バージョン \(version)）には対応していません。新しいバージョンの シフト手帳 でお試しください。"
            } catch {
                errorMessage = "ファイルを読み込めませんでした。シフト手帳 で書き出した JSON を選んでください。"
            }
        case .failure:
            errorMessage = "ファイルを開けませんでした。もう一度選び直してください。"
        }
    }

    private func performImport(strategy: ShiftTechoStore.ImportStrategy) {
        guard let document = pendingImport else { return }
        store.importBackup(document, strategy: strategy)
        pendingImport = nil
        infoMessage = "\(document.assignments.count)件のシフトを読み込みました。"
        Task { await environment.refreshNotifications() }
    }

    private func deleteAll() {
        store.deleteAllData()
        exportedURL = nil
        infoMessage = nil
        Task { await environment.refreshNotifications() }
        onResetToOnboarding()
    }
}
