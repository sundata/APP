import Foundation
import SwiftUI
import ShiftTechoCore

/// 依存性注入のコンテナ。View は具体実装を知らない。
@MainActor
final class AppEnvironment {
    let store: ShiftTechoStore
    let notificationScheduler: NotificationScheduling
    let backupProvider: BackupProviding
    let entitlements: StoreKitEntitlementProvider
    let clock: ClockProviding
    /// UI テスト・スクリーンショット時は広告とネットワークを使わない。
    let isTestingMode: Bool

    init(
        store: ShiftTechoStore,
        notificationScheduler: NotificationScheduling,
        backupProvider: BackupProviding = FileBackupProvider(),
        entitlements: StoreKitEntitlementProvider = StoreKitEntitlementProvider(),
        clock: ClockProviding = SystemClock(),
        isTestingMode: Bool = false
    ) {
        self.store = store
        self.notificationScheduler = notificationScheduler
        self.backupProvider = backupProvider
        self.entitlements = entitlements
        self.clock = clock
        self.isTestingMode = isTestingMode
    }

    /// 実機・シミュレータ用の既定構成。
    static func live(store: ShiftTechoStore) -> AppEnvironment {
        #if canImport(UserNotifications)
        let notifications: NotificationScheduling = LocalNotificationScheduler()
        #else
        let notifications: NotificationScheduling = StubNotificationScheduler()
        #endif
        return AppEnvironment(store: store, notificationScheduler: notifications)
    }

    /// UI テスト用。権限ダイアログと広告を使わず、時計も固定する。
    /// 起動引数 `-uiTesting` で有効になる。
    static func uiTesting(store: ShiftTechoStore) -> AppEnvironment {
        let fixed = Date(timeIntervalSince1970: 1_772_323_200) // 2026-03-01 09:00 JST
        return AppEnvironment(
            store: store,
            notificationScheduler: StubNotificationScheduler(granted: false),
            entitlements: StoreKitEntitlementProvider(isTesting: true),
            clock: FixedClock(fixed),
            isTestingMode: true
        )
    }

    /// 今日（Asia/Tokyo）の dayKey。
    var todayDayKey: String {
        ShiftTechoCalendar.dayKey(for: clock.now)
    }

    /// 通知の再登録。シフトを変更したあとに呼ぶ。
    func refreshNotifications() async {
        let settings = store.settings()
        let reminders = settings.reminderSettings

        if reminders.monthlyReminderEnabled {
            await notificationScheduler.scheduleMonthlyReminder(
                day: reminders.monthlyReminderDay,
                minuteOfDay: reminders.monthlyReminderMinuteOfDay
            )
        } else {
            await notificationScheduler.cancelMonthlyReminder()
        }

        if reminders.nextShiftReminderEnabled {
            let today = todayDayKey
            let upcoming = store.allEntries()
                .filter { $0.dayKey >= today && $0.definition.kind == .work }
                .prefix(NotificationLimits.nextShiftHorizonDays)
                .map { UpcomingShift(assignment: $0.assignment) }
            await notificationScheduler.scheduleNextShiftReminders(
                Array(upcoming),
                minuteOfDay: reminders.nextShiftReminderMinuteOfDay
            )
        } else {
            await notificationScheduler.cancelNextShiftReminders()
        }
    }
}
