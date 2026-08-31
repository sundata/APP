import SwiftUI
import SwiftData
import ShiftTechoCore

/// 初回ガイドと 3 タブの切り替え。
@MainActor
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    private let environment: AppEnvironment
    @State private var adMob = AdMobProvider.shared
    @State private var onboardingCompleted: Bool

    init(container: ModelContainer) {
        let store = ShiftTechoStore(context: ModelContext(container))
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-uiTesting")
        let isScreenshotTesting = arguments.contains("-screenshotTesting")
        let environment = (isUITesting || isScreenshotTesting)
            ? AppEnvironment.uiTesting(store: store)
            : AppEnvironment.live(store: store)
        if isScreenshotTesting {
            // スクリーンショット用にテンプレートと数日分のシフトだけを用意する。
            let templates = store.seedDefaultTemplatesIfNeeded()
            store.updatePayrollSettings(PayrollSettings(hourlyWageYen: 1_300))
            let month = CalendarMonth.containing(environment.clock.now)
            for (index, dayKey) in month.dayKeys.enumerated() where index % 3 != 2 {
                let template = templates[index % templates.count]
                store.assign(dayKey: dayKey, templateID: template.id, definition: template.definition)
            }
            store.completeOnboarding()
        }
        self.environment = environment
        _onboardingCompleted = State(initialValue: store.settings().onboardingCompleted)
    }

    var body: some View {
        Group {
            if onboardingCompleted {
                TabView {
                    CalendarTabView(environment: environment)
                        .tabItem { Label("カレンダー", systemImage: "calendar") }
                    PayrollSummaryView(environment: environment)
                        .tabItem { Label("集計", systemImage: "yensign.circle") }
                    SettingsView(environment: environment) {
                        onboardingCompleted = false
                    }
                    .tabItem { Label("設定", systemImage: "gearshape") }
                }
                .tint(ShiftTechoTheme.accent)
            } else {
                OnboardingView(environment: environment) {
                    onboardingCompleted = true
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, onboardingCompleted else { return }
            // 設定から戻ったときの権限変化を通知登録に反映する。
            Task { await environment.refreshNotifications() }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            // 広告はタブバーとシートを遮らない位置に置く。ガイド・共有・削除確認では表示しない。
            if onboardingCompleted, adMob.canShowAds, !environment.isTestingMode {
                AdMobBannerView(adUnitID: AdMobProvider.bannerAdUnitID)
                    .background(.ultraThinMaterial)
            }
        }
        .task {
            guard !environment.isTestingMode else { return }
            await adMob.prepare()
        }
    }
}
