import Foundation
import SwiftData
import KoyomiCore

/// ユーザー設定（端末内のみ）。行はひとつだけ持つ。
@Model
final class UserSettingsRecord {
    var onboardingCompleted: Bool
    /// 基礎時給（円）。未設定のときは nil。
    var hourlyWageYen: Int?
    /// 夜間加算率。25% は 2500。
    var nightPremiumBasisPoints: Int
    var overtimePremiumBasisPoints: Int
    var nightStartMinute: Int
    var nightEndMinute: Int
    var standardDailyMinutes: Int
    var transportAllowancePerWorkdayYen: Int
    var monthlyReminderEnabled: Bool
    var monthlyReminderDay: Int
    var monthlyReminderMinuteOfDay: Int
    var nextShiftReminderEnabled: Bool
    var nextShiftReminderMinuteOfDay: Int
    /// 集計タブの金額をぼかす設定（App スイッチャー対策）。
    var hidesAmountsWhenInactive: Bool
    var backupSchemaVersion: Int
    var updatedAt: Date

    init(
        onboardingCompleted: Bool = false,
        hourlyWageYen: Int? = nil,
        payrollSettings: PayrollSettings = PayrollSettings(),
        reminderSettings: ReminderSettings = ReminderSettings(),
        hidesAmountsWhenInactive: Bool = false,
        backupSchemaVersion: Int = BackupDocument.currentSchemaVersion,
        updatedAt: Date = Date()
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.hourlyWageYen = hourlyWageYen ?? payrollSettings.hourlyWageYen
        self.nightPremiumBasisPoints = payrollSettings.nightPremiumBasisPoints
        self.overtimePremiumBasisPoints = payrollSettings.overtimePremiumBasisPoints
        self.nightStartMinute = payrollSettings.nightStartMinute
        self.nightEndMinute = payrollSettings.nightEndMinute
        self.standardDailyMinutes = payrollSettings.standardDailyMinutes
        self.transportAllowancePerWorkdayYen = payrollSettings.transportAllowancePerWorkdayYen
        self.monthlyReminderEnabled = reminderSettings.monthlyReminderEnabled
        self.monthlyReminderDay = reminderSettings.monthlyReminderDay
        self.monthlyReminderMinuteOfDay = reminderSettings.monthlyReminderMinuteOfDay
        self.nextShiftReminderEnabled = reminderSettings.nextShiftReminderEnabled
        self.nextShiftReminderMinuteOfDay = reminderSettings.nextShiftReminderMinuteOfDay
        self.hidesAmountsWhenInactive = hidesAmountsWhenInactive
        self.backupSchemaVersion = backupSchemaVersion
        self.updatedAt = updatedAt
    }

    var payrollSettings: PayrollSettings {
        get {
            PayrollSettings(
                hourlyWageYen: hourlyWageYen,
                nightPremiumBasisPoints: nightPremiumBasisPoints,
                overtimePremiumBasisPoints: overtimePremiumBasisPoints,
                nightStartMinute: nightStartMinute,
                nightEndMinute: nightEndMinute,
                standardDailyMinutes: standardDailyMinutes,
                transportAllowancePerWorkdayYen: transportAllowancePerWorkdayYen
            )
        }
        set {
            hourlyWageYen = newValue.hourlyWageYen
            nightPremiumBasisPoints = newValue.nightPremiumBasisPoints
            overtimePremiumBasisPoints = newValue.overtimePremiumBasisPoints
            nightStartMinute = newValue.nightStartMinute
            nightEndMinute = newValue.nightEndMinute
            standardDailyMinutes = newValue.standardDailyMinutes
            transportAllowancePerWorkdayYen = newValue.transportAllowancePerWorkdayYen
            updatedAt = Date()
        }
    }

    var reminderSettings: ReminderSettings {
        get {
            ReminderSettings(
                monthlyReminderEnabled: monthlyReminderEnabled,
                monthlyReminderDay: monthlyReminderDay,
                monthlyReminderMinuteOfDay: monthlyReminderMinuteOfDay,
                nextShiftReminderEnabled: nextShiftReminderEnabled,
                nextShiftReminderMinuteOfDay: nextShiftReminderMinuteOfDay
            )
        }
        set {
            monthlyReminderEnabled = newValue.monthlyReminderEnabled
            monthlyReminderDay = newValue.monthlyReminderDay
            monthlyReminderMinuteOfDay = newValue.monthlyReminderMinuteOfDay
            nextShiftReminderEnabled = newValue.nextShiftReminderEnabled
            nextShiftReminderMinuteOfDay = newValue.nextShiftReminderMinuteOfDay
            updatedAt = Date()
        }
    }
}

/// シフトテンプレート。編集しても過去の登録には影響しない。
@Model
final class ShiftTemplateRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var kindRawValue: String
    var startMinute: Int?
    var endMinute: Int?
    var crossesMidnight: Bool
    var breakMinutes: Int
    var colorRawValue: String
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        definition: ShiftDefinition,
        sortOrder: Int,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = definition.name
        self.kindRawValue = definition.kind.rawValue
        self.startMinute = definition.startMinute
        self.endMinute = definition.endMinute
        self.crossesMidnight = definition.crossesMidnight
        self.breakMinutes = definition.breakMinutes
        self.colorRawValue = definition.color.rawValue
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var definition: ShiftDefinition {
        get {
            ShiftDefinition(
                name: name,
                kind: ShiftKind(rawValue: kindRawValue) ?? .work,
                startMinute: startMinute,
                endMinute: endMinute,
                crossesMidnight: crossesMidnight,
                breakMinutes: breakMinutes,
                color: ShiftColor(rawValue: colorRawValue) ?? .gray
            )
        }
        set {
            name = newValue.name
            kindRawValue = newValue.kind.rawValue
            startMinute = newValue.startMinute
            endMinute = newValue.endMinute
            crossesMidnight = newValue.crossesMidnight
            breakMinutes = newValue.breakMinutes
            colorRawValue = newValue.color.rawValue
            updatedAt = Date()
        }
    }

    var template: ShiftTemplate {
        ShiftTemplate(id: id, definition: definition, sortOrder: sortOrder, isArchived: isArchived)
    }
}

/// 1 日 1 件のシフト登録。テンプレートのスナップショットを持つため、
/// 後からテンプレートを編集しても過去の工時は変化しない。
@Model
final class ShiftEntryRecord {
    @Attribute(.unique) var dayKey: String
    var id: UUID
    var templateID: UUID?
    var name: String
    var kindRawValue: String
    var startMinute: Int?
    var endMinute: Int?
    var crossesMidnight: Bool
    var breakMinutes: Int
    var colorRawValue: String
    /// 端末内のみに保存するメモ。共有画像・通知には出さない。
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        dayKey: String,
        templateID: UUID?,
        definition: ShiftDefinition,
        note: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dayKey = dayKey
        self.templateID = templateID
        self.name = definition.name
        self.kindRawValue = definition.kind.rawValue
        self.startMinute = definition.startMinute
        self.endMinute = definition.endMinute
        self.crossesMidnight = definition.crossesMidnight
        self.breakMinutes = definition.breakMinutes
        self.colorRawValue = definition.color.rawValue
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var definition: ShiftDefinition {
        get {
            ShiftDefinition(
                name: name,
                kind: ShiftKind(rawValue: kindRawValue) ?? .work,
                startMinute: startMinute,
                endMinute: endMinute,
                crossesMidnight: crossesMidnight,
                breakMinutes: breakMinutes,
                color: ShiftColor(rawValue: colorRawValue) ?? .gray
            )
        }
        set {
            name = newValue.name
            kindRawValue = newValue.kind.rawValue
            startMinute = newValue.startMinute
            endMinute = newValue.endMinute
            crossesMidnight = newValue.crossesMidnight
            breakMinutes = newValue.breakMinutes
            colorRawValue = newValue.color.rawValue
            updatedAt = Date()
        }
    }

    var assignment: ShiftAssignment {
        ShiftAssignment(id: id, dayKey: dayKey, templateID: templateID, definition: definition, note: note)
    }
}
