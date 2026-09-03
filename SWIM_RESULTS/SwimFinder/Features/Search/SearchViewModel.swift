import Foundation
import Observation
import SwimFinderCore

/// 選手検索・大会検索の原生検索フロー。
@MainActor
@Observable
final class SearchViewModel {
    enum Kind {
        case player
        case meet
    }

    let kind: Kind
    var rawQuery = ""
    var affiliationQuery = ""
    var fiscalYear: Int?
    var prefectureCode: Int?
    var statusCode: Int?
    var waterwayCode: Int?
    private(set) var errorMessage: String?
    private(set) var isLoading = false
    private(set) var hasSearched = false
    private(set) var players: [PlayerSummary] = []
    private(set) var meets: [MeetSummary] = []

    private let store: LocalStore
    private let clock: ClockProviding
    private let provider: SwimResultsProviding

    init(kind: Kind, environment: AppEnvironment) {
        self.kind = kind
        self.store = environment.store
        self.clock = environment.clock
        self.provider = environment.resultsProvider
    }

    var normalizedQuery: String { QueryNormalizer.normalize(rawQuery) }
    var canSubmit: Bool {
        switch kind {
        case .player: return QueryNormalizer.isSearchable(rawQuery) || QueryNormalizer.isSearchable(affiliationQuery)
        case .meet:
            return QueryNormalizer.isSearchable(rawQuery) || fiscalYear != nil || prefectureCode != nil || statusCode != nil || waterwayCode != nil
        }
    }

    /// 選択可能な年度（公式サイトは年度単位で大会を管理している）。
    var selectableYears: [Int] {
        let current = Calendar(identifier: .gregorian).component(.year, from: clock.now())
        return Array((current - 5)...(current + 1)).reversed()
    }

    func search() async {
        guard canSubmit, !isLoading else { return }
        isLoading = true
        hasSearched = true
        errorMessage = nil
        let now = clock.now()
        defer { isLoading = false }
        do {
            switch kind {
            case .player:
                players = try await provider.searchPlayers(query: PlayerQuery(rawName: rawQuery, rawAffiliation: affiliationQuery))
                meets = []
                let affiliationOnly = normalizedQuery.isEmpty
                let historyText = affiliationOnly ? QueryNormalizer.normalize(affiliationQuery) : normalizedQuery
                store.recordSearch(RecentSearch(kind: affiliationOnly ? .affiliation : .player, rawQuery: historyText, officialURL: OfficialSite.playerSearch, searchedAt: now))
            case .meet:
                meets = try await provider.searchMeets(query: MeetQuery(rawName: rawQuery, fiscalYear: fiscalYear, prefectureCode: prefectureCode, statusCode: statusCode, waterwayCode: waterwayCode))
                players = []
                let historyText = normalizedQuery.isEmpty ? meetFilterSummary : rawQuery
                store.recordSearch(RecentSearch(kind: .meet, rawQuery: historyText, fiscalYear: fiscalYear, prefectureCode: prefectureCode, statusCode: statusCode, waterwayCode: waterwayCode, isFilterOnly: normalizedQuery.isEmpty, officialURL: OfficialSite.tournamentList, searchedAt: now))
            }
        } catch let error as SwimResultsError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = "検索に失敗しました。時間をおいて再度お試しください。"
        }
    }

    private var meetFilterSummary: String {
        var parts: [String] = []
        if let prefectureCode, let name = Self.prefectures.first(where: { $0.code == prefectureCode })?.name { parts.append(name) }
        if let waterwayCode { parts.append(waterwayCode == 1 ? "長水路" : "短水路") }
        if let statusCode, let name = Self.statuses.first(where: { $0.code == statusCode })?.name { parts.append(name) }
        return parts.isEmpty ? "大会検索" : parts.joined(separator: "・")
    }

    static let prefectures: [(code: Int, name: String)] = [
        "北海道","青森","岩手","宮城","秋田","山形","福島","茨城","栃木","群馬","埼玉","千葉","東京","神奈川","山梨","長野","新潟","富山","石川","福井","静岡","愛知","三重","岐阜","滋賀","京都","大阪","兵庫","奈良","和歌山","鳥取","島根","岡山","広島","山口","香川","徳島","愛媛","高知","福岡","佐賀","長崎","熊本","大分","宮崎","鹿児島","沖縄"
    ].enumerated().map { (code: $0.offset + 1, name: $0.element) }
    static let statuses: [(code: Int, name: String)] = [
        (0, "中止"), (6, "延期"), (1, "開催前"), (2, "エントリー済み"),
        (3, "開催中"), (4, "大会終了"), (5, "記録確定"), (7, "記録未登録")
    ]

    func clearMessages() {
        errorMessage = nil
        players = []
        meets = []
        hasSearched = false
    }
}
