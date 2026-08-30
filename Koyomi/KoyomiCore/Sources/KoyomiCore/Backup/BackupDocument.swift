import Foundation

/// リマインダー設定。バックアップにも含めるので KoyomiCore で定義する。
public struct ReminderSettings: Codable, Hashable, Sendable {
    public var monthlyReminderEnabled: Bool
    /// 毎月の入力リマインダーの日（1〜28）。
    public var monthlyReminderDay: Int
    public var monthlyReminderMinuteOfDay: Int
    public var nextShiftReminderEnabled: Bool
    /// 前日に知らせる時刻（0 時からの経過分）。
    public var nextShiftReminderMinuteOfDay: Int

    public init(
        monthlyReminderEnabled: Bool = false,
        monthlyReminderDay: Int = 25,
        monthlyReminderMinuteOfDay: Int = 20 * 60,
        nextShiftReminderEnabled: Bool = false,
        nextShiftReminderMinuteOfDay: Int = 20 * 60
    ) {
        self.monthlyReminderEnabled = monthlyReminderEnabled
        self.monthlyReminderDay = min(max(monthlyReminderDay, 1), 28)
        self.monthlyReminderMinuteOfDay = PayrollSettings.clampMinuteOfDay(monthlyReminderMinuteOfDay)
        self.nextShiftReminderEnabled = nextShiftReminderEnabled
        self.nextShiftReminderMinuteOfDay = PayrollSettings.clampMinuteOfDay(nextShiftReminderMinuteOfDay)
    }
}

/// JSON バックアップの中身。端末内のデータだけを持ち、サーバーには送らない。
public struct BackupDocument: Codable, Hashable, Sendable {
    /// 現在の書式バージョン。読み込み時に必ず検証する。
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var payrollSettings: PayrollSettings
    public var reminderSettings: ReminderSettings
    public var templates: [ShiftTemplate]
    public var assignments: [ShiftAssignment]

    public init(
        schemaVersion: Int = BackupDocument.currentSchemaVersion,
        exportedAt: Date,
        payrollSettings: PayrollSettings,
        reminderSettings: ReminderSettings,
        templates: [ShiftTemplate],
        assignments: [ShiftAssignment]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.payrollSettings = payrollSettings
        self.reminderSettings = reminderSettings
        self.templates = templates
        self.assignments = assignments
    }
}

/// バックアップ読み込みの失敗理由。UI では日本語の対処方法に変換する。
public enum BackupError: Error, Equatable, Sendable {
    /// JSON として読めない。
    case malformed
    /// 書式バージョンが対応範囲外。
    case unsupportedSchemaVersion(Int)
    /// 日付キーなどの内容が壊れている。
    case invalidContent
}

/// バックアップの書き出し・読み込み。
public enum BackupCodec {
    public static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    public static func decode(_ data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: BackupDocument
        do {
            document = try decoder.decode(BackupDocument.self, from: data)
        } catch {
            throw BackupError.malformed
        }
        guard document.schemaVersion == BackupDocument.currentSchemaVersion else {
            throw BackupError.unsupportedSchemaVersion(document.schemaVersion)
        }
        guard document.assignments.allSatisfy({ KoyomiCalendar.date(fromDayKey: $0.dayKey) != nil }) else {
            throw BackupError.invalidContent
        }
        // 同じ日が 2 件入っていても、1 日 1 件の原則を崩さない。
        var seen = Set<String>()
        var assignments: [ShiftAssignment] = []
        for assignment in document.assignments where seen.insert(assignment.dayKey).inserted {
            assignments.append(assignment)
        }
        var normalized = document
        normalized.assignments = assignments
        return normalized
    }

    /// 書き出しファイル名（例: koyomi-backup-2026-08-30.json）。
    public static func fileName(exportedAt: Date, calendar: Calendar = KoyomiCalendar.japan) -> String {
        "koyomi-backup-\(KoyomiCalendar.dayKey(for: exportedAt, calendar: calendar)).json"
    }
}
