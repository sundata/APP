import Foundation
import KoyomiCore
#if canImport(UserNotifications)
import UserNotifications
#endif

/// 毎日のリマインダー。ユーザーが自分でオンにするまで権限を要求しない。
protocol NotificationScheduling: Sendable {
    /// 権限を要求する。許可されたら true。
    func requestAuthorization() async -> Bool
    func scheduleDailyReminder(hour: Int, minute: Int) async
    func cancelDailyReminder() async
}

#if canImport(UserNotifications)
struct LocalNotificationScheduler: NotificationScheduling {
    static let reminderIdentifier = "koyomi.daily.reminder"

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Koyomi"
        // 不安をあおる文面は使わない（コンテンツ側でも検査している）。
        content.body = ContentLibrary.notificationMessages[
            abs(hour * 60 + minute) % ContentLibrary.notificationMessages.count
        ]
        content.sound = .default

        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.reminderIdentifier,
            content: content,
            trigger: trigger
        )
        try? await center.add(request)
    }

    func cancelDailyReminder() async {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [Self.reminderIdentifier])
    }
}
#endif

/// テスト・プレビュー用。権限ダイアログを出さない。
final class StubNotificationScheduler: NotificationScheduling, @unchecked Sendable {
    private(set) var authorizationRequested = false
    private(set) var scheduledTime: DateComponents?
    private let granted: Bool

    init(granted: Bool = true) {
        self.granted = granted
    }

    func requestAuthorization() async -> Bool {
        authorizationRequested = true
        return granted
    }

    func scheduleDailyReminder(hour: Int, minute: Int) async {
        scheduledTime = DateComponents(hour: hour, minute: minute)
    }

    func cancelDailyReminder() async {
        scheduledTime = nil
    }
}
