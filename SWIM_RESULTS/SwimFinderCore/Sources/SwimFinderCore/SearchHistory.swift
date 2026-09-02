import Foundation

/// 直近検索の 1 件。検索条件と公式 URL のみを保持し、結果本文は保持しない。
public struct RecentSearch: Sendable, Hashable, Codable, Identifiable {
    public enum Kind: String, Sendable, Codable, CaseIterable {
        case player
        case meet

        public var title: String {
            switch self {
            case .player: return "選手"
            case .meet: return "大会"
            }
        }
    }

    public let id: UUID
    public let kind: Kind
    /// 入力原文
    public let rawQuery: String
    /// 正規化済み検索語（重複判定に使う）
    public let normalizedQuery: String
    public let fiscalYear: Int?
    public let officialURL: URL
    public let searchedAt: Date

    public init(id: UUID = UUID(), kind: Kind, rawQuery: String, fiscalYear: Int? = nil, officialURL: URL, searchedAt: Date) {
        self.id = id
        self.kind = kind
        self.rawQuery = rawQuery
        self.normalizedQuery = QueryNormalizer.normalize(rawQuery)
        self.fiscalYear = fiscalYear
        self.officialURL = officialURL
        self.searchedAt = searchedAt
    }

    /// 同じ種類・同じ正規化検索語・同じ年度なら同一の検索とみなす。
    public var dedupeKey: String {
        "\(kind.rawValue)|\(normalizedQuery)|\(fiscalYear.map(String.init) ?? "")"
    }
}

/// 履歴の保持ルール（端末内のみ・最大 10 件・新しい順・重複は最新で置き換え）。
public enum SearchHistoryPolicy {
    public static let maxCount = 10

    public static func appending(_ item: RecentSearch, to history: [RecentSearch]) -> [RecentSearch] {
        var kept = history.filter { $0.dedupeKey != item.dedupeKey }
        kept.insert(item, at: 0)
        kept.sort { $0.searchedAt > $1.searchedAt }
        return Array(kept.prefix(maxCount))
    }

    /// 空白のみ・1 文字などは履歴に残さない。
    public static func shouldRecord(rawQuery: String) -> Bool {
        QueryNormalizer.isSearchable(rawQuery)
    }
}

/// お気に入り（公式 URL のブックマーク）。公式サイト以外の URL は保存できない。
public struct FavoriteLink: Sendable, Hashable, Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let url: URL
    public let kind: OfficialSite.PageKind
    public let createdAt: Date

    public init?(id: UUID = UUID(), title: String, url: URL, createdAt: Date) {
        guard let kind = OfficialSite.pageKind(of: url) else { return nil }
        let trimmed = QueryNormalizer.normalize(title)
        self.id = id
        self.title = trimmed.isEmpty ? url.absoluteString : trimmed
        self.url = url
        self.kind = kind
        self.createdAt = createdAt
    }
}
