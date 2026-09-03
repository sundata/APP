import SwiftData
import SwiftUI

@main
struct SwimFinderApp: App {
    private let container: ModelContainer
    private let environment: AppEnvironment

    init() {
        let schema = Schema([RecentSearchRecord.self, FavoriteRecord.self, PerformanceGoalRecord.self, RacePlanRecord.self, AthletePreferenceRecord.self])
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-uiTesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer の初期化に失敗しました: \(error)")
        }
        let clipboard: ClipboardWriting = isUITesting ? RecordingClipboard() : SystemClipboard()
        environment = AppEnvironment(
            store: LocalStore(context: container.mainContext),
            clipboard: clipboard,
            clock: SystemClock(),
            isUITesting: isUITesting
        )
        if !isUITesting {
            environment.resultUpdateMonitor.registerBackgroundRefresh()
            environment.resultUpdateMonitor.scheduleBackgroundRefresh()
        }
        if isUITesting, arguments.contains("-seedHistory") {
            environment.store.seedForUITests()
        }
        if isUITesting, arguments.contains("-seedFreeAthleteLimit") {
            environment.store.seedFreeAthleteLimitForUITests()
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.store)
        }
        .modelContainer(container)
    }
}
