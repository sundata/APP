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
    var officialURLString: String
    var searchedAt: Date

    init(_ item: RecentSearch) {
        id = item.id
        kindRawValue = item.kind.rawValue
        rawQuery = item.rawQuery
        normalizedQuery = item.normalizedQuery
        fiscalYear = item.fiscalYear
        officialURLString = item.officialURL.absoluteString
        searchedAt = item.searchedAt
    }

    var item: RecentSearch? {
        guard let kind = RecentSearch.Kind(rawValue: kindRawValue), let url = URL(string: officialURLString) else { return nil }
        return RecentSearch(id: id, kind: kind, rawQuery: rawQuery, fiscalYear: fiscalYear, officialURL: url, searchedAt: searchedAt)
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
