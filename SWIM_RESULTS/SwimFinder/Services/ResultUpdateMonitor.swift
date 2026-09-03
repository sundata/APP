import Foundation
import UserNotifications
import BackgroundTasks
import SwimFinderCore

@MainActor
final class ResultUpdateMonitor {
    static let backgroundIdentifier = "jp.co.sundata.swimfinder.results-refresh"
    private let provider: SwimResultsProviding
    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter

    init(provider: SwimResultsProviding, defaults: UserDefaults = .standard, center: UNUserNotificationCenter = .current()) {
        self.provider = provider
        self.defaults = defaults
        self.center = center
    }

    var isEnabled: Bool {
        get { defaults.bool(forKey: "resultNotificationsEnabled") }
        set { defaults.set(newValue, forKey: "resultNotificationsEnabled") }
    }

    var lastCheckedAt: Date? { defaults.object(forKey: "resultLastCheckedAt") as? Date }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            isEnabled = granted
            if granted { scheduleBackgroundRefresh() }
            return granted
        } catch {
            isEnabled = false
            return false
        }
    }

    /// 起動時・手動更新時に公式データとの差分を確認する。初回は基準値だけを保存する。
    func check(athletes: [(id: String, name: String)]) async {
        syncWatchedAthletes(athletes)
        guard isEnabled else { return }
        for athlete in athletes {
            guard let results = try? await provider.playerResults(playerID: athlete.id) else { continue }
            let signature = results.map { "\($0.id)|\($0.time)|\($0.remark ?? "")" }.sorted().joined(separator: ";")
            let key = "resultSignature.\(athlete.id)"
            let old = defaults.string(forKey: key)
            defaults.set(signature, forKey: key)
            guard let old, old != signature, let latest = results.max(by: { ($0.resultDate ?? "") < ($1.resultDate ?? "") }) else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(athlete.name)選手の成績が更新されました"
            content.body = "\(latest.eventName)  \(latest.time.isEmpty ? latest.remark ?? "結果更新" : latest.time)"
            content.sound = .default
            try? await center.add(UNNotificationRequest(identifier: "result.\(athlete.id).\(latest.id)", content: content, trigger: nil))
        }
        defaults.set(Date(), forKey: "resultLastCheckedAt")
        scheduleBackgroundRefresh()
    }

    func syncWatchedAthletes(_ athletes: [(id: String, name: String)]) {
        defaults.set(athletes.map { ["id": $0.id, "name": $0.name] }, forKey: "watchedAthletes")
    }

    func clearLocalState() {
        defaults.removeObject(forKey: "watchedAthletes")
        defaults.removeObject(forKey: "resultLastCheckedAt")
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("resultSignature.") {
            defaults.removeObject(forKey: key)
        }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    func scheduleRaceReminder(for item: RacePlanItem) async -> Bool {
        guard let minutes = item.reminderMinutes else { return false }
        let settings = await center.notificationSettings()
        var authorized = settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
        if settings.authorizationStatus == .notDetermined {
            authorized = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        }
        guard authorized else { return false }

        let interval = item.scheduledAt.addingTimeInterval(TimeInterval(-minutes * 60)).timeIntervalSinceNow
        guard interval > 0 else { return false }
        let content = UNMutableNotificationContent()
        content.title = "まもなく (item.athleteName)選手のレースです"
        content.body = [item.eventName, item.heat.isEmpty ? nil : "\(item.heat)組", item.lane.isEmpty ? nil : "\(item.lane)レーン"].compactMap { $0 }.joined(separator: "  ·  ")
        content.sound = .default
        let request = UNNotificationRequest(identifier: raceReminderIdentifier(item.id), content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
        do {
            try await center.add(request)
            return true
        } catch {
            return false
        }
    }

    func cancelRaceReminder(id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [raceReminderIdentifier(id)])
        center.removeDeliveredNotifications(withIdentifiers: [raceReminderIdentifier(id)])
    }

    private func raceReminderIdentifier(_ id: UUID) -> String { "racePlan.\(id.uuidString)" }

    func registerBackgroundRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.backgroundIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                guard let self else { refreshTask.setTaskCompleted(success: false); return }
                let rows = self.defaults.array(forKey: "watchedAthletes") as? [[String: String]] ?? []
                let athletes = rows.compactMap { row -> (id: String, name: String)? in
                    guard let id = row["id"], let name = row["name"] else { return nil }
                    return (id, name)
                }
                let operation = Task { await self.check(athletes: athletes) }
                refreshTask.expirationHandler = { operation.cancel() }
                await operation.value
                refreshTask.setTaskCompleted(success: !operation.isCancelled)
            }
        }
    }

    func scheduleBackgroundRefresh() {
        guard isEnabled else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.backgroundIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
