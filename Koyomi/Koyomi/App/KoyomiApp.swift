import SwiftUI
import SwiftData
import KoyomiCore

@main
struct KoyomiApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([UserPreferencesRecord.self, FortuneRecord.self])
        // UI テストではディスクを汚さないため、インメモリで動かす。
        let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isUITesting)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // 保存領域が使えない場合でも占い自体は表示できるようにする。
            container = try! ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }
}
