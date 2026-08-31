import SwiftUI
import SwiftData
import KoyomiCore

@main
struct KoyomiApp: App {
    private let container: ModelContainer

    init() {
        let schema = Schema([UserSettingsRecord.self, ShiftTemplateRecord.self, ShiftEntryRecord.self])
        // UI テストではディスクを汚さないため、インメモリで動かす。
        let arguments = ProcessInfo.processInfo.arguments
        let usesEphemeralStore = arguments.contains("-uiTesting") || arguments.contains("-screenshotTesting")
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: usesEphemeralStore)
        do {
            container = try ModelContainer(for: schema, configurations: configuration)
        } catch {
            // 旧バージョン（占い）のストアが残っていて開けない場合は、
            // 起動を止めずに新しいストアを作り直す。占いデータは移行対象がないため破棄する。
            KoyomiApp.removeLegacyStore()
            do {
                container = try ModelContainer(for: schema, configurations: configuration)
            } catch {
                container = try! ModelContainer(
                    for: schema,
                    configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                )
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(container: container)
        }
    }

    /// 既定の SwiftData ストアを削除する。スキーマが噛み合わない旧データを捨てるための最後の手段。
    private static func removeLegacyStore() {
        let fileManager = FileManager.default
        guard let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? fileManager.removeItem(at: support.appendingPathComponent(name))
        }
    }
}
