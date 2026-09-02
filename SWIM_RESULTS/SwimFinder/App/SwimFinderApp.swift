import SwiftData
import SwiftUI

@main
struct SwimFinderApp: App {
    private let container: ModelContainer
    private let environment: AppEnvironment

    init() {
        let schema = Schema([RecentSearchRecord.self, FavoriteRecord.self])
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
        if isUITesting, arguments.contains("-seedHistory") {
            environment.store.seedForUITests()
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
