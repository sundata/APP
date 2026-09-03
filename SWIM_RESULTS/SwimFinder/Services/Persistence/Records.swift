import Foundation
import SwiftData
import SwimFinderCore

/// 直近検索の永続化。検索条件と公式 URL のみ保存し、結果本文は保存しない。
@Model
final class RecentSearchRecord {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var rawQuery: String
    var normalizedQuery: String
    var fiscalYear: Int?
    var prefectureCode: Int?
    var statusCode: Int?
    var waterwayCode: Int?
    var isFilterOnly: Bool?
    var officialURLString: String
    var searchedAt: Date

    init(_ item: RecentSearch) {
        id = item.id
        kindRawValue = item.kind.rawValue
        rawQuery = item.rawQuery
        normalizedQuery = item.normalizedQuery
        fiscalYear = item.fiscalYear
        prefectureCode = item.prefectureCode
        statusCode = item.statusCode
        waterwayCode = item.waterwayCode
        isFilterOnly = item.isFilterOnly
        officialURLString = item.officialURL.absoluteString
        searchedAt = item.searchedAt
    }

    var item: RecentSearch? {
        guard let kind = RecentSearch.Kind(rawValue: kindRawValue), let url = URL(string: officialURLString) else { return nil }
        return RecentSearch(id: id, kind: kind, rawQuery: rawQuery, fiscalYear: fiscalYear, prefectureCode: prefectureCode, statusCode: statusCode, waterwayCode: waterwayCode, isFilterOnly: isFilterOnly ?? false, officialURL: url, searchedAt: searchedAt)
    }
}

/// お気に入り（公式 URL のブックマーク）の永続化。
@Model
final class FavoriteRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var urlString: String
    var kindRawValue: String
    var createdAt: Date

    init(_ link: FavoriteLink) {
        id = link.id
        title = link.title
        urlString = link.url.absoluteString
        kindRawValue = link.kind.rawValue
        createdAt = link.createdAt
    }

    var link: FavoriteLink? {
        guard let url = URL(string: urlString) else { return nil }
        return FavoriteLink(id: id, title: title, url: url, createdAt: createdAt)
    }
}

struct PerformanceGoal: Identifiable, Hashable {
    let id: UUID
    let athleteID: String
    let athleteName: String
    let eventName: String
    let targetSeconds: Double
    let createdAt: Date
}

@Model
final class PerformanceGoalRecord {
    @Attribute(.unique) var id: UUID
    var athleteID: String
    var athleteName: String
    var eventName: String
    var targetSeconds: Double
    var createdAt: Date

    init(_ goal: PerformanceGoal) {
        id = goal.id
        athleteID = goal.athleteID
        athleteName = goal.athleteName
        eventName = goal.eventName
        targetSeconds = goal.targetSeconds
        createdAt = goal.createdAt
    }

    var goal: PerformanceGoal {
        PerformanceGoal(id: id, athleteID: athleteID, athleteName: athleteName, eventName: eventName, targetSeconds: targetSeconds, createdAt: createdAt)
    }
}

struct RacePlanItem: Identifiable, Hashable {
    enum Status: String, CaseIterable { case upcoming = "待機中", warmingUp = "ウォームアップ", finished = "終了" }
    let id: UUID
    let athleteID: String
    let athleteName: String
    let eventName: String
    let meetName: String
    let scheduledAt: Date
    let heat: String
    let lane: String
    let status: Status
    let reminderMinutes: Int?
}

@Model
final class RacePlanRecord {
    @Attribute(.unique) var id: UUID
    var athleteID: String
    var athleteName: String
    var eventName: String
    var meetName: String
    var scheduledAt: Date
    var heat: String
    var lane: String
    var statusRawValue: String
    var reminderMinutes: Int?

    init(_ item: RacePlanItem) {
        id = item.id; athleteID = item.athleteID; athleteName = item.athleteName
        eventName = item.eventName; meetName = item.meetName; scheduledAt = item.scheduledAt
        heat = item.heat; lane = item.lane; statusRawValue = item.status.rawValue
        reminderMinutes = item.reminderMinutes
    }

    var item: RacePlanItem? {
        guard let status = RacePlanItem.Status(rawValue: statusRawValue) else { return nil }
        return RacePlanItem(id: id, athleteID: athleteID, athleteName: athleteName, eventName: eventName, meetName: meetName, scheduledAt: scheduledAt, heat: heat, lane: lane, status: status, reminderMinutes: reminderMinutes)
    }
}

struct AthletePreference: Identifiable, Hashable {
    var id: String { athleteID }
    let athleteID: String
    var nickname: String
    var groupName: String
    var sortOrder: Int
}

@Model
final class AthletePreferenceRecord {
    @Attribute(.unique) var athleteID: String
    var nickname: String
    var groupName: String
    var sortOrder: Int

    init(_ item: AthletePreference) {
        athleteID = item.athleteID; nickname = item.nickname
        groupName = item.groupName; sortOrder = item.sortOrder
    }

    var item: AthletePreference {
        AthletePreference(athleteID: athleteID, nickname: nickname, groupName: groupName, sortOrder: sortOrder)
    }
}
