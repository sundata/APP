import SwiftUI
import KoyomiCore

/// 設定タブ。テンプレート・給与ルール・通知・データ・プライバシー。
@MainActor
struct SettingsView: View {
    private let environment: AppEnvironment
    /// すべてのデータを削除したあと、初回起動状態に戻すためのコールバック。
    private let onResetToOnboarding: () -> Void

    init(environment: AppEnvironment, onResetToOnboarding: @escaping () -> Void) {
        self.environment = environment
        self.onResetToOnboarding = onResetToOnboarding
    }

    var body: some View {
        NavigationStack {
            List {
                Section("シフト") {
                    NavigationLink("シフトテンプレート") {
                        ShiftTemplateListView(environment: environment)
                    }
                    .accessibilityIdentifier("settingsTemplatesLink")
                }

                Section("給与") {
                    NavigationLink("給与ルール") {
                        PayrollSettingsView(store: environment.store)
                    }
                    .accessibilityIdentifier("settingsPayrollLink")
                }

                Section("通知") {
                    NavigationLink("リマインダー") {
                        ReminderSettingsView(environment: environment)
                    }
                    .accessibilityIdentifier("settingsRemindersLink")
                }

                Section("データ") {
                    NavigationLink("バックアップと削除") {
                        DataManagementView(environment: environment, onResetToOnboarding: onResetToOnboarding)
                    }
                    .accessibilityIdentifier("settingsDataLink")
                }

                Section("このアプリについて") {
                    NavigationLink("プライバシーについて") {
                        KoyomiLegalTextView()
                    }
                    LabeledContent("バージョン", value: Bundle.appVersionText)
                }
            }
            .navigationTitle("設定")
        }
    }
}

extension Bundle {
    static var appVersionText: String {
        let version = main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
