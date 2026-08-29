import SwiftUI
import SwiftData
import KoyomiCore

/// onboarding と 3 タブの切り替え。
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase

    private let environment: AppEnvironment
    @State private var onboardingCompleted: Bool
    @State private var todayViewModel: TodayViewModel

    init(container: ModelContainer) {
        let store = KoyomiStore(context: ModelContext(container))
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let environment = isUITesting ? AppEnvironment.uiTesting(store: store) : AppEnvironment.live(store: store)
        self.environment = environment
        _onboardingCompleted = State(initialValue: store.preferences().onboardingCompleted)
        _todayViewModel = State(initialValue: TodayViewModel(environment: environment))
    }

    var body: some View {
        Group {
            if onboardingCompleted {
                TabView {
                    TodayView(viewModel: todayViewModel)
                        .tabItem { Label("今日", systemImage: "sun.and.horizon") }
                    CalendarView(environment: environment)
                        .tabItem { Label("カレンダー", systemImage: "calendar") }
                    ProfileView(environment: environment) {
                        onboardingCompleted = false
                    }
                    .tabItem { Label("わたし", systemImage: "person") }
                }
            } else {
                OnboardingView(environment: environment) {
                    onboardingCompleted = true
                    Task { await todayViewModel.load() }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, onboardingCompleted else { return }
            // 設定から戻ったときの権限変化と、ローカル日付の切り替わりを反映する。
            Task { await todayViewModel.load() }
        }
    }
}
