import Foundation
import SwiftData
import KoyomiCore

/// SwiftData への入口。View から直接 ModelContext を触らないための層。
@MainActor
@Observable
final class KoyomiStore {
    /// 直前の操作を 1 回だけ戻すためのスナップショット。
    struct UndoSnapshot {
        let title: String
        fileprivate let dayKeys: [String]
        fileprivate let previous: [String: ShiftAssignment]
    }

    private let context: ModelContext
    /// 直近の登録・削除。UI の Undo 表示に使う。
    private(set) var undoSnapshot: UndoSnapshot?
    /// 変更のたびに増える。View の再描画トリガー。
    private(set) var revision = 0

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - 設定

    func settings() -> UserSettingsRecord {
        let descriptor = FetchDescriptor<UserSettingsRecord>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserSettingsRecord()
        context.insert(created)
        save()
        return created
    }

    func updatePayrollSettings(_ newValue: PayrollSettings) {
        let record = settings()
        record.payrollSettings = newValue
        save()
    }

    func updateReminderSettings(_ newValue: ReminderSettings) {
        let record = settings()
        record.reminderSettings = newValue
        save()
    }

    func completeOnboarding() {
        let record = settings()
        record.onboardingCompleted = true
        record.updatedAt = Date()
        save()
    }

    func save() {
        try? context.save()
        revision += 1
    }

    // MARK: - テンプレート

    /// 未アーカイブのテンプレート（並び順）。
    func activeTemplates() -> [ShiftTemplateRecord] {
        allTemplates().filter { !$0.isArchived }
    }

    func allTemplates() -> [ShiftTemplateRecord] {
        let descriptor = FetchDescriptor<ShiftTemplateRecord>(sortBy: [SortDescriptor(\.sortOrder)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func template(id: UUID) -> ShiftTemplateRecord? {
        allTemplates().first { $0.id == id }
    }

    /// 初回起動時に既定テンプレートを入れる。すでに 1 件でもあれば何もしない。
    @discardableResult
    func seedDefaultTemplatesIfNeeded() -> [ShiftTemplateRecord] {
        let existing = allTemplates()
        guard existing.isEmpty else { return existing }
        for template in ShiftTemplate.defaults {
            context.insert(
                ShiftTemplateRecord(id: template.id, definition: template.definition, sortOrder: template.sortOrder)
            )
        }
        save()
        return allTemplates()
    }

    var canAddTemplate: Bool {
        activeTemplates().count < ShiftTemplate.activeLimit
    }

    @discardableResult
    func addTemplate(_ definition: ShiftDefinition, id: UUID = UUID()) -> ShiftTemplateRecord? {
        guard canAddTemplate, definition.hasValidName else { return nil }
        let sortOrder = (allTemplates().map(\.sortOrder).max() ?? -1) + 1
        let record = ShiftTemplateRecord(id: id, definition: definition, sortOrder: sortOrder)
        context.insert(record)
        save()
        return record
    }

    func updateTemplate(id: UUID, definition: ShiftDefinition) {
        guard definition.hasValidName, let record = template(id: id) else { return }
        record.definition = definition
        save()
    }

    /// 使用済みテンプレートは消さずアーカイブする。
    func archiveTemplate(id: UUID) {
        guard let record = template(id: id) else { return }
        record.isArchived = true
        record.updatedAt = Date()
        save()
    }

    func unarchiveTemplate(id: UUID) {
        guard canAddTemplate, let record = template(id: id) else { return }
        record.isArchived = false
        record.updatedAt = Date()
        save()
    }

    /// 過去のシフトで使われているかどうか。使用済みなら削除させない。
    func isTemplateUsed(id: UUID) -> Bool {
        var descriptor = FetchDescriptor<ShiftEntryRecord>(predicate: #Predicate { $0.templateID == id })
        descriptor.fetchLimit = 1
        return ((try? context.fetch(descriptor)) ?? []).isEmpty == false
    }

    /// 未使用テンプレートのみ削除できる。使用済みは自動でアーカイブに切り替える。
    func deleteTemplate(id: UUID) {
        guard let record = template(id: id) else { return }
        if isTemplateUsed(id: id) {
            archiveTemplate(id: id)
            return
        }
        context.delete(record)
        save()
    }

    func moveTemplates(_ ordered: [UUID]) {
        for (index, id) in ordered.enumerated() {
            guard let record = template(id: id) else { continue }
            record.sortOrder = index
            record.updatedAt = Date()
        }
        save()
    }

    // MARK: - シフト登録

    func entry(dayKey: String) -> ShiftEntryRecord? {
        var descriptor = FetchDescriptor<ShiftEntryRecord>(predicate: #Predicate { $0.dayKey == dayKey })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func entries(dayKeys: [String]) -> [String: ShiftEntryRecord] {
        let keys = Set(dayKeys)
        let descriptor = FetchDescriptor<ShiftEntryRecord>()
        let all = (try? context.fetch(descriptor)) ?? []
        return Dictionary(uniqueKeysWithValues: all.filter { keys.contains($0.dayKey) }.map { ($0.dayKey, $0) })
    }

    func assignments(dayKeys: [String]) -> [String: ShiftAssignment] {
        entries(dayKeys: dayKeys).mapValues(\.assignment)
    }

    func allEntries() -> [ShiftEntryRecord] {
        let descriptor = FetchDescriptor<ShiftEntryRecord>(sortBy: [SortDescriptor(\.dayKey)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 1 日 1 件。同じ日に登録し直したときは既存レコードを更新する。
    @discardableResult
    func assign(
        dayKey: String,
        templateID: UUID?,
        definition: ShiftDefinition,
        note: String = "",
        undoTitle: String? = nil
    ) -> ShiftEntryRecord? {
        guard KoyomiCalendar.date(fromDayKey: dayKey) != nil else { return nil }
        captureUndo(dayKeys: [dayKey], title: undoTitle ?? "シフトを登録しました")
        let record = upsert(dayKey: dayKey, templateID: templateID, definition: definition, note: note)
        save()
        return record
    }

    /// 連続した日付にまとめて登録する。上限は 62 日。
    @discardableResult
    func assignRange(
        dayKeys: [String],
        templateID: UUID?,
        definition: ShiftDefinition
    ) -> Int {
        let keys = Array(dayKeys.prefix(Self.bulkAssignmentLimit))
        guard !keys.isEmpty else { return 0 }
        captureUndo(dayKeys: keys, title: "\(keys.count)日分をまとめて登録しました")
        for key in keys where KoyomiCalendar.date(fromDayKey: key) != nil {
            upsert(dayKey: key, templateID: templateID, definition: definition, note: entry(dayKey: key)?.note ?? "")
        }
        save()
        return keys.count
    }

    /// 範囲内で上書きされる既存シフトの件数。
    func existingAssignmentCount(dayKeys: [String]) -> Int {
        entries(dayKeys: dayKeys).count
    }

    func deleteEntry(dayKey: String) {
        guard let record = entry(dayKey: dayKey) else { return }
        captureUndo(dayKeys: [dayKey], title: "シフトを削除しました")
        context.delete(record)
        save()
    }

    /// 直前の登録・削除・一括操作を元に戻す。
    func undoLastChange() {
        guard let snapshot = undoSnapshot else { return }
        for key in snapshot.dayKeys {
            if let previous = snapshot.previous[key] {
                upsert(
                    dayKey: key,
                    templateID: previous.templateID,
                    definition: previous.definition,
                    note: previous.note,
                    id: previous.id
                )
            } else if let record = entry(dayKey: key) {
                context.delete(record)
            }
        }
        undoSnapshot = nil
        save()
    }

    func clearUndo() {
        undoSnapshot = nil
    }

    // MARK: - バックアップ

    func backupDocument(exportedAt: Date = Date()) -> BackupDocument {
        let record = settings()
        return BackupDocument(
            exportedAt: exportedAt,
            payrollSettings: record.payrollSettings,
            reminderSettings: record.reminderSettings,
            templates: allTemplates().map(\.template),
            assignments: allEntries().map(\.assignment)
        )
    }

    enum ImportStrategy {
        /// 既存データを残し、同じ日付は取り込み側で上書きする。
        case merge
        /// 既存データを消してから取り込む。
        case replace
    }

    /// 検証済みドキュメントを取り込む。失敗しても既存データは壊さない
    /// （`BackupCodec.decode` を通ってから呼ばれる）。
    func importBackup(_ document: BackupDocument, strategy: ImportStrategy) {
        if strategy == .replace {
            deleteAllData(keepSettingsRow: true)
        }

        let record = settings()
        record.payrollSettings = document.payrollSettings
        record.reminderSettings = document.reminderSettings
        record.onboardingCompleted = true
        record.backupSchemaVersion = document.schemaVersion

        for template in document.templates {
            if let existing = self.template(id: template.id) {
                existing.definition = template.definition
                existing.sortOrder = template.sortOrder
                existing.isArchived = template.isArchived
            } else {
                context.insert(
                    ShiftTemplateRecord(
                        id: template.id,
                        definition: template.definition,
                        sortOrder: template.sortOrder,
                        isArchived: template.isArchived
                    )
                )
            }
        }

        for assignment in document.assignments {
            upsert(
                dayKey: assignment.dayKey,
                templateID: assignment.templateID,
                definition: assignment.definition,
                note: assignment.note,
                id: assignment.id
            )
        }
        undoSnapshot = nil
        save()
    }

    // MARK: - データ削除

    /// 設定画面の「すべてのデータを削除」。端末内のデータを完全に消す。
    func deleteAllData(keepSettingsRow: Bool = false) {
        for record in allEntries() {
            context.delete(record)
        }
        for record in allTemplates() {
            context.delete(record)
        }
        if !keepSettingsRow {
            let descriptor = FetchDescriptor<UserSettingsRecord>()
            for record in (try? context.fetch(descriptor)) ?? [] {
                context.delete(record)
            }
        }
        undoSnapshot = nil
        save()
    }

    // MARK: - 内部

    static let bulkAssignmentLimit = 62

    @discardableResult
    private func upsert(
        dayKey: String,
        templateID: UUID?,
        definition: ShiftDefinition,
        note: String,
        id: UUID? = nil
    ) -> ShiftEntryRecord {
        if let existing = entry(dayKey: dayKey) {
            existing.templateID = templateID
            existing.definition = definition
            existing.note = String(note.prefix(ShiftAssignment.noteLengthLimit))
            existing.updatedAt = Date()
            return existing
        }
        let record = ShiftEntryRecord(
            id: id ?? UUID(),
            dayKey: dayKey,
            templateID: templateID,
            definition: definition,
            note: String(note.prefix(ShiftAssignment.noteLengthLimit))
        )
        context.insert(record)
        return record
    }

    private func captureUndo(dayKeys: [String], title: String) {
        let previous = assignments(dayKeys: dayKeys)
        undoSnapshot = UndoSnapshot(title: title, dayKeys: dayKeys, previous: previous)
    }
}
