import SwiftUI
import ShiftTechoCore

/// 設定タブ。テンプレート・給与ルール・通知・データ・プライバシー。
@MainActor
struct SettingsView: View {
    private let environment: AppEnvironment
    @State private var adMob = AdMobProvider.shared
    /// すべてのデータを削除したあと、初回起動状態に戻すためのコールバック。
    private let onResetToOnboarding: () -> Void
    @State private var showsPremium = false

    init(environment: AppEnvironment, onResetToOnboarding: @escaping () -> Void) {
        self.environment = environment
        self.onResetToOnboarding = onResetToOnboarding
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button { showsPremium = true } label: {
                        HStack {
                            Label("シフト手帳プレミアム", systemImage: "sparkles")
                            Spacer()
                            Text(environment.entitlements.isPro ? "利用中" : "詳しく見る")
                                .font(.caption)
                                .foregroundStyle(environment.entitlements.isPro ? ShiftTechoTheme.accent : .secondary)
                        }
                    }
                    .disabled(environment.entitlements.isPro)
                }

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
                        ShiftTechoLegalTextView()
                    }
                    LabeledContent("バージョン", value: Bundle.appVersionText)
                }

                // 設定画面では一覧の末尾に置き、操作項目へ重ねない。
                if adMob.canShowAds, !environment.isTestingMode, !environment.entitlements.isPro {
                    Section("広告") {
                        AdMobBannerView(adUnitID: AdMobProvider.bannerAdUnitID)
                            .frame(maxWidth: .infinity)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showsPremium) {
                PremiumPaywallView(entitlements: environment.entitlements)
            }
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
