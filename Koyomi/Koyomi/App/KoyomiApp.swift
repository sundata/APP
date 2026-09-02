import SwiftUI
import SwiftData
import KoyomiCore

@main
struct KoyomiApp: App {
    private let container: ModelContainer

    init() {
        // 新規インストール直後でもSwiftDataが保存先を確実に作成できるようにする。
        // CoreData任せの復旧は成功しても、大量のエラーログと起動遅延が発生する。
        if let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            try? FileManager.default.createDirectory(
                at: applicationSupportURL,
                withIntermediateDirectories: true
            )
        }

        let schema = Schema([UserPreferencesRecord.self, FortuneRecord.self, DailyMoodRecord.self, DailyRitualRecord.self])
        // UI テストではディスクを汚さないため、インメモリで動かす。
        let arguments = ProcessInfo.processInfo.arguments
        let usesEphemeralStore = arguments.contains("-uiTesting")
            || arguments.contains("-uiTestingCurrentLocation")
            || arguments.contains("-screenshotTesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: usesEphemeralStore)
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
