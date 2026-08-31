import Foundation
import KoyomiCore
#if canImport(UserNotifications)
import UserNotifications
#endif

/// 通知の上限に関する定数。
enum NotificationLimits {
    /// 先読みして登録する翌日通知の日数。iOS の保留通知上限に収まる範囲にする。
    static let nextShiftHorizonDays = 30
}

/// 通知の許可状態。設定案内の出し分けに使う。
enum NotificationPermission: Sendable {
    case notDetermined
    case granted
    case denied
}

/// ローカル通知。ユーザーが自分でスイッチを入れるまで権限を要求しない。
/// 通知本文に給与とメモは含めない。
protocol NotificationScheduling: Sendable {
    func permission() async -> NotificationPermission
    /// 権限を要求する。許可されたら true。
    func requestAuthorization() async -> Bool
    /// 毎月の登録リマインダー。
    func scheduleMonthlyReminder(day: Int, minuteOfDay: Int) async
    func cancelMonthlyReminder() async
    /// 翌日のシフト通知。前日 `minuteOfDay` に通知する。
    func scheduleNextShiftReminders(_ shifts: [UpcomingShift], minuteOfDay: Int) async
    func cancelNextShiftReminders() async
}

/// 通知に載せる最小限の情報。メモと金額は持たない。
struct UpcomingShift: Hashable, Sendable {
    let dayKey: String
    let name: String
    /// 勤務開始（0 時からの経過分）。休みでは nil。
    let startMinute: Int?

    init(assignment: ShiftAssignment) {
        dayKey = assignment.dayKey
        name = assignment.definition.name
        startMinute = assignment.definition.startMinute
    }

    init(dayKey: String, name: String, startMinute: Int?) {
        self.dayKey = dayKey
        self.name = name
        self.startMinute = startMinute
    }

    /// 「3月1日（日）夜勤 22:00〜」のような本文。
    var bodyText: String {
        guard let date = KoyomiCalendar.date(fromDayKey: dayKey) else { return name }
        let day = KoyomiCalendar.displayDate(for: date)
        guard let startMinute else { return "\(day) は \(name) です。" }
        return "\(day) は \(name)（\(KoyomiCalendar.timeText(minuteOfDay: startMinute)) 開始）です。"
    }
}

#if canImport(UserNotifications)
struct LocalNotificationScheduler: NotificationScheduling {
    static let monthlyIdentifier = "koyomi.reminder.monthly"
    static let nextShiftPrefix = "koyomi.reminder.nextShift."

    func permission() async -> NotificationPermission {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        default: return .granted
        }
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleMonthlyReminder(day: Int, minuteOfDay: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.monthlyIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Koyomi"
        content.body = "来月のシフトを登録しましょう。"
        content.sound = .default

        var components = DateComponents()
        components.day = min(max(day, 1), 28)
        components.hour = minuteOfDay / 60
        components.minute = minuteOfDay % 60
        components.timeZone = KoyomiCalendar.japan.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        try? await center.add(
            UNNotificationRequest(identifier: Self.monthlyIdentifier, content: content, trigger: trigger)
        )
    }

    func cancelMonthlyReminder() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.monthlyIdentifier])
    }

    func scheduleNextShiftReminders(_ shifts: [UpcomingShift], minuteOfDay: Int) async {
        let center = UNUserNotificationCenter.current()
        await cancelNextShiftReminders()

        let calendar = KoyomiCalendar.japan
        let now = Date()
        for shift in shifts.prefix(NotificationLimits.nextShiftHorizonDays) {
            // 夜勤も「開始日の前日」に通知する。開始日そのものは本文で示す。
            guard let shiftDate = KoyomiCalendar.date(fromDayKey: shift.dayKey),
                  let previousDay = calendar.date(byAdding: .day, value: -1, to: shiftDate),
                  let fireDate = calendar.date(
                      bySettingHour: minuteOfDay / 60,
                      minute: minuteOfDay % 60,
                      second: 0,
                      of: previousDay
                  ),
                  fireDate > now
            else { continue }

            let content = UNMutableNotificationContent()
            content.title = "あすのシフト"
            content.body = shift.bodyText
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try? await center.add(
                UNNotificationRequest(
                    identifier: Self.nextShiftPrefix + shift.dayKey,
                    content: content,
                    trigger: trigger
                )
            )
        }
    }

    func cancelNextShiftReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(Self.nextShiftPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
#endif

/// テスト・プレビュー用。権限ダイアログを出さない。
final class StubNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var authorizationRequested = false
    private(set) var monthlyReminder: DateComponents?
    private(set) var nextShiftReminders: [UpcomingShift] = []
    private var status: NotificationPermission
    private let granted: Bool

    init(granted: Bool = true, initialPermission: NotificationPermission = .notDetermined) {
        self.granted = granted
        self.status = initialPermission
    }

    func permission() async -> NotificationPermission { status }

    func requestAuthorization() async -> Bool {
        authorizationRequested = true
        status = granted ? .granted : .denied
        return granted
    }

    func scheduleMonthlyReminder(day: Int, minuteOfDay: Int) async {
        monthlyReminder = DateComponents(day: day, hour: minuteOfDay / 60, minute: minuteOfDay % 60)
    }

    func cancelMonthlyReminder() async {
        monthlyReminder = nil
    }

    func scheduleNextShiftReminders(_ shifts: [UpcomingShift], minuteOfDay: Int) async {
        nextShiftReminders = shifts
    }

    func cancelNextShiftReminders() async {
        nextShiftReminders = []
    }
}
