import XCTest
@testable import SwimFinderCore

final class SearchHistoryAndLaunchTests: XCTestCase {
    private let base = Date(timeIntervalSince1970: 1_800_000_000)

    private func search(_ raw: String, kind: RecentSearch.Kind = .player, year: Int? = nil, offset: TimeInterval) -> RecentSearch {
        RecentSearch(kind: kind, rawQuery: raw, fiscalYear: year, officialURL: OfficialSite.playerSearch, searchedAt: base.addingTimeInterval(offset))
    }

    func testHistoryKeepsAtMostTenNewestFirst() {
        var history: [RecentSearch] = []
        for i in 0..<15 {
            history = SearchHistoryPolicy.appending(search("選手\(i)", offset: Double(i)), to: history)
        }
        XCTAssertEqual(history.count, SearchHistoryPolicy.maxCount)
        XCTAssertEqual(history.first?.rawQuery, "選手14")
        XCTAssertEqual(history.last?.rawQuery, "選手5")
    }

    func testHistoryDedupesByNormalizedQuery() {
        var history = SearchHistoryPolicy.appending(search("山田 花子", offset: 0), to: [])
        history = SearchHistoryPolicy.appending(search("鈴木", offset: 1), to: history)
        history = SearchHistoryPolicy.appending(search(" 山田\u{3000}花子 ", offset: 2), to: history)
        XCTAssertEqual(history.count, 2)
        XCTAssertEqual(history.first?.rawQuery, " 山田\u{3000}花子 ")
    }

    func testHistoryDistinguishesKindAndYear() {
        var history = SearchHistoryPolicy.appending(search("日本選手権", kind: .meet, year: 2025, offset: 0), to: [])
        history = SearchHistoryPolicy.appending(search("日本選手権", kind: .meet, year: 2026, offset: 1), to: history)
        history = SearchHistoryPolicy.appending(search("日本選手権", kind: .player, offset: 2), to: history)
        XCTAssertEqual(history.count, 3)
    }

    func testShouldRecord() {
        XCTAssertFalse(SearchHistoryPolicy.shouldRecord(rawQuery: " "))
        XCTAssertFalse(SearchHistoryPolicy.shouldRecord(rawQuery: "山"))
        XCTAssertTrue(SearchHistoryPolicy.shouldRecord(rawQuery: "山田"))
    }

    func testPlayerLaunchPlan() throws {
        let plan = try OfficialSiteLaunch.player(PlayerQuery(rawName: "  山田\u{3000}花子 "), now: base).get()
        XCTAssertEqual(plan.url, OfficialSite.playerSearch)
        XCTAssertEqual(plan.clipboardText, "山田 花子")
        XCTAssertEqual(plan.historyItem?.kind, .player)
        XCTAssertEqual(plan.historyItem?.rawQuery, "  山田\u{3000}花子 ")
        XCTAssertTrue(plan.guidance.contains("選手名"))
    }

    func testMeetLaunchPlanWithYear() throws {
        let plan = try OfficialSiteLaunch.meet(MeetQuery(rawName: "日本選手権", fiscalYear: 2026), now: base).get()
        XCTAssertEqual(plan.url, OfficialSite.tournamentList)
        XCTAssertEqual(plan.historyItem?.fiscalYear, 2026)
        XCTAssertTrue(plan.guidance.contains("2026年度"))
    }

    func testLaunchRejectsEmptyAndShortQueries() {
        XCTAssertEqual(OfficialSiteLaunch.player(PlayerQuery(rawName: "   "), now: base), .failure(.emptyQuery))
        XCTAssertEqual(OfficialSiteLaunch.meet(MeetQuery(rawName: "大"), now: base), .failure(.tooShort(minimum: 2)))
    }

    func testReopenOnlyOfficialURLs() {
        XCTAssertNil(OfficialSiteLaunch.reopen(URL(string: "https://example.com/")!))
        let plan = OfficialSiteLaunch.reopen(URL(string: "https://result.swim.or.jp/athletes/1")!)
        XCTAssertEqual(plan?.clipboardText, "")
        XCTAssertNil(plan?.historyItem)
    }

    func testRecentSearchRoundTripsThroughCodable() throws {
        let item = search("山田 花子", kind: .meet, year: 2026, offset: 0)
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(RecentSearch.self, from: data)
        XCTAssertEqual(decoded, item)
    }
}
