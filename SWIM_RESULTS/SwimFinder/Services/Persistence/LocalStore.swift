import Foundation
import Observation
import SwiftData
import SwimFinderCore

/// 端末内の履歴・お気に入りストア。外部送信は一切行わない。
@MainActor
@Observable
final class LocalStore {
    private let context: ModelContext
    private(set) var recentSearches: [RecentSearch] = []
    private(set) var favorites: [FavoriteLink] = []
    private(set) var goals: [PerformanceGoal] = []
    private(set) var racePlans: [RacePlanItem] = []
    private(set) var athletePreferences: [AthletePreference] = []
    private(set) var lastError: String?

    init(context: ModelContext) {
        self.context = context
        reload()
    }

    // MARK: 履歴

    func recordSearch(_ item: RecentSearch) {
        guard SearchHistoryPolicy.shouldRecord(rawQuery: item.rawQuery) else { return }
        let updated = SearchHistoryPolicy.appending(item, to: recentSearches)
        replaceAllRecents(with: updated)
    }

    func deleteRecent(_ item: RecentSearch) {
        replaceAllRecents(with: recentSearches.filter { $0.id != item.id })
    }

    func clearRecents() {
        replaceAllRecents(with: [])
    }

    private func replaceAllRecents(with items: [RecentSearch]) {
        do {
            try context.delete(model: RecentSearchRecord.self)
            for item in items { context.insert(RecentSearchRecord(item)) }
            try context.save()
            recentSearches = items
            lastError = nil
        } catch {
            lastError = "履歴の保存に失敗しました。"
        }
    }

    // MARK: お気に入り

    func isFavorite(_ url: URL) -> Bool {
        favorites.contains { $0.url == url }
    }

    /// 公式 URL 以外は保存しない。既に同じ URL があれば何もしない。
    @discardableResult
    func addFavorite(title: String, url: URL) -> Bool {
        guard !isFavorite(url), let link = FavoriteLink(title: title, url: url, createdAt: Date()) else { return false }
        context.insert(FavoriteRecord(link))
        return persistFavorites()
    }

    @discardableResult
    func removeFavorite(_ link: FavoriteLink) -> [UUID] {
        removeFavorite(url: link.url)
    }

    @discardableResult
    func removeFavorite(url: URL) -> [UUID] {
        let target = url.absoluteString
        let athleteID = url.pathComponents.contains("athletes") ? url.pathComponents.filter { $0 != "/" }.last : nil
        let reminderIDs = athleteID.map { id in racePlans.filter { $0.athleteID == id }.map(\.id) } ?? []
        let descriptor = FetchDescriptor<FavoriteRecord>(predicate: #Predicate { $0.urlString == target })
        do {
            for record in try context.fetch(descriptor) { context.delete(record) }
            if let athleteID { try deleteAthleteData(athleteID: athleteID) }
        } catch {
            lastError = "お気に入りの削除に失敗しました。"
        }
        persistFavorites()
        return reminderIDs
    }

    func clearFavorites() {
        do {
            try context.delete(model: FavoriteRecord.self)
            try context.delete(model: PerformanceGoalRecord.self)
            try context.delete(model: RacePlanRecord.self)
            try context.delete(model: AthletePreferenceRecord.self)
        } catch {
            lastError = "お気に入りの削除に失敗しました。"
        }
        persistFavorites()
    }

    /// 検索履歴・お気に入り・目標・当日プラン・表示設定を一括削除する。
    func clearAllLocalData() {
        do {
            try context.delete(model: RecentSearchRecord.self)
            try context.delete(model: FavoriteRecord.self)
            try context.delete(model: PerformanceGoalRecord.self)
            try context.delete(model: RacePlanRecord.self)
            try context.delete(model: AthletePreferenceRecord.self)
            try context.save()
            reload()
            lastError = nil
        } catch {
            lastError = "端末内データの削除に失敗しました。"
        }
    }

    private func deleteAthleteData(athleteID: String) throws {
        let goalDescriptor = FetchDescriptor<PerformanceGoalRecord>(predicate: #Predicate { $0.athleteID == athleteID })
        let planDescriptor = FetchDescriptor<RacePlanRecord>(predicate: #Predicate { $0.athleteID == athleteID })
        let preferenceDescriptor = FetchDescriptor<AthletePreferenceRecord>(predicate: #Predicate { $0.athleteID == athleteID })
        try context.fetch(goalDescriptor).forEach(context.delete)
        try context.fetch(planDescriptor).forEach(context.delete)
        try context.fetch(preferenceDescriptor).forEach(context.delete)
    }

    // MARK: 目標タイム

    func goal(athleteID: String, eventName: String) -> PerformanceGoal? {
        goals.first { $0.athleteID == athleteID && $0.eventName == eventName }
    }

    func setGoal(athleteID: String, athleteName: String, eventName: String, targetSeconds: Double) {
        guard targetSeconds > 0 else { return }
        let existing = goals.filter { $0.athleteID == athleteID && $0.eventName == eventName }
        existing.forEach(deleteGoal)
        context.insert(PerformanceGoalRecord(PerformanceGoal(id: UUID(), athleteID: athleteID, athleteName: athleteName, eventName: eventName, targetSeconds: targetSeconds, createdAt: Date())))
        persistGoals()
    }

    func deleteGoal(_ goal: PerformanceGoal) {
        let id = goal.id
        let descriptor = FetchDescriptor<PerformanceGoalRecord>(predicate: #Predicate { $0.id == id })
        do { for record in try context.fetch(descriptor) { context.delete(record) } }
        catch { lastError = "目標タイムの削除に失敗しました。" }
        persistGoals()
    }

    private func persistGoals() {
        do { try context.save(); reload(); lastError = nil }
        catch { lastError = "目標タイムの保存に失敗しました。" }
    }

    // MARK: 大会当日プラン

    @discardableResult
    func addRacePlan(athleteID: String, athleteName: String, eventName: String, meetName: String, scheduledAt: Date, heat: String, lane: String, reminderMinutes: Int? = nil) -> RacePlanItem {
        let item = RacePlanItem(id: UUID(), athleteID: athleteID, athleteName: athleteName, eventName: eventName, meetName: meetName, scheduledAt: scheduledAt, heat: heat, lane: lane, status: .upcoming, reminderMinutes: reminderMinutes)
        context.insert(RacePlanRecord(item))
        persistRacePlans()
        return item
    }

    func setRacePlanStatus(_ item: RacePlanItem, status: RacePlanItem.Status) {
        let id = item.id
        let descriptor = FetchDescriptor<RacePlanRecord>(predicate: #Predicate { $0.id == id })
        do { try context.fetch(descriptor).forEach { $0.statusRawValue = status.rawValue } }
        catch { lastError = "当日プランの更新に失敗しました。" }
        persistRacePlans()
    }

    @discardableResult
    func updateRacePlan(_ item: RacePlanItem, athleteID: String, athleteName: String, eventName: String, meetName: String, scheduledAt: Date, heat: String, lane: String, reminderMinutes: Int?) -> RacePlanItem {
        let updated = RacePlanItem(id: item.id, athleteID: athleteID, athleteName: athleteName, eventName: eventName, meetName: meetName, scheduledAt: scheduledAt, heat: heat, lane: lane, status: item.status, reminderMinutes: reminderMinutes)
        let id = item.id
        let descriptor = FetchDescriptor<RacePlanRecord>(predicate: #Predicate { $0.id == id })
        do {
            for record in try context.fetch(descriptor) {
                record.athleteID = athleteID
                record.athleteName = athleteName
                record.eventName = eventName
                record.meetName = meetName
                record.scheduledAt = scheduledAt
                record.heat = heat
                record.lane = lane
                record.reminderMinutes = reminderMinutes
            }
        } catch {
            lastError = "当日プランの更新に失敗しました。"
        }
        persistRacePlans()
        return updated
    }

    @discardableResult
    func deleteRacePlans(at offsets: IndexSet) -> [UUID] {
        let targets = offsets.map { racePlans[$0].id }
        do {
            for id in targets {
                let descriptor = FetchDescriptor<RacePlanRecord>(predicate: #Predicate { $0.id == id })
                try context.fetch(descriptor).forEach(context.delete)
            }
        } catch { lastError = "当日プランの削除に失敗しました。" }
        persistRacePlans()
        return targets
    }

    private func persistRacePlans() {
        do { try context.save(); reload(); lastError = nil }
        catch { lastError = "当日プランの保存に失敗しました。" }
    }

    // MARK: 選手表示設定

    func preference(for athleteID: String) -> AthletePreference? {
        athletePreferences.first { $0.athleteID == athleteID }
    }

    func displayName(officialName: String, athleteID: String) -> String {
        let nickname = preference(for: athleteID)?.nickname.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return nickname.isEmpty ? officialName : nickname
    }

    func setAthletePreference(athleteID: String, nickname: String, groupName: String) {
        let old = preference(for: athleteID)
        replacePreference(AthletePreference(athleteID: athleteID, nickname: nickname, groupName: groupName, sortOrder: old?.sortOrder ?? athletePreferences.count))
    }

    func reorderAthletes(_ athleteIDs: [String]) {
        for (index, id) in athleteIDs.enumerated() {
            let old = preference(for: id) ?? AthletePreference(athleteID: id, nickname: "", groupName: "", sortOrder: index)
            replacePreference(AthletePreference(athleteID: id, nickname: old.nickname, groupName: old.groupName, sortOrder: index), savesImmediately: false)
        }
        persistPreferences()
    }

    private func replacePreference(_ item: AthletePreference, savesImmediately: Bool = true) {
        let id = item.athleteID
        let descriptor = FetchDescriptor<AthletePreferenceRecord>(predicate: #Predicate { $0.athleteID == id })
        do {
            try context.fetch(descriptor).forEach(context.delete)
            context.insert(AthletePreferenceRecord(item))
            if savesImmediately { persistPreferences() }
        } catch { lastError = "選手表示設定の保存に失敗しました。" }
    }

    private func persistPreferences() {
        do { try context.save(); reload(); lastError = nil }
        catch { lastError = "選手表示設定の保存に失敗しました。" }
    }

    @discardableResult
    private func persistFavorites() -> Bool {
        do {
            try context.save()
            reload()
            lastError = nil
            return true
        } catch {
            lastError = "お気に入りの保存に失敗しました。"
            return false
        }
    }

    // MARK: 読み込み

    func reload() {
        let recentDescriptor = FetchDescriptor<RecentSearchRecord>(sortBy: [SortDescriptor(\.searchedAt, order: .reverse)])
        let favoriteDescriptor = FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let goalDescriptor = FetchDescriptor<PerformanceGoalRecord>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        let racePlanDescriptor = FetchDescriptor<RacePlanRecord>(sortBy: [SortDescriptor(\.scheduledAt)])
        let preferenceDescriptor = FetchDescriptor<AthletePreferenceRecord>(sortBy: [SortDescriptor(\.sortOrder)])
        do {
            recentSearches = Array(try context.fetch(recentDescriptor).compactMap(\.item).prefix(SearchHistoryPolicy.maxCount))
            favorites = try context.fetch(favoriteDescriptor).compactMap(\.link)
            goals = try context.fetch(goalDescriptor).map(\.goal)
            racePlans = try context.fetch(racePlanDescriptor).compactMap(\.item)
            athletePreferences = try context.fetch(preferenceDescriptor).map(\.item)
        } catch {
            lastError = "保存データの読み込みに失敗しました。"
        }
    }

    // MARK: UI テスト用シード

    func seedForUITests() {
        let now = Date()
        recordSearch(RecentSearch(kind: .player, rawQuery: "架空 太郎", officialURL: OfficialSite.playerSearch, searchedAt: now.addingTimeInterval(-60)))
        recordSearch(RecentSearch(kind: .meet, rawQuery: "サンプル市民水泳大会", fiscalYear: 2026, officialURL: OfficialSite.tournamentList, searchedAt: now))
        addFavorite(title: "選手検索（公式）", url: OfficialSite.playerSearch)
        if let athleteURL = OfficialSite.athlete(id: "900001") {
            addFavorite(title: "架空 太郎", url: athleteURL)
        }
    }

    func seedFreeAthleteLimitForUITests() {
        for (id, name) in [("800001", "テスト選手A"), ("800002", "テスト選手B")] {
            if let url = OfficialSite.athlete(id: id) { addFavorite(title: name, url: url) }
        }
    }
}
