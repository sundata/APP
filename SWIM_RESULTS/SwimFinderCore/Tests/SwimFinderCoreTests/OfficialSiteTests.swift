import XCTest
@testable import SwimFinderCore

final class OfficialSiteTests: XCTestCase {
    func testStaticURLs() {
        XCTAssertEqual(OfficialSite.playerSearch.absoluteString, "https://result.swim.or.jp/player-search")
        XCTAssertEqual(OfficialSite.tournamentList.absoluteString, "https://result.swim.or.jp/tournament/list")
        XCTAssertNil(OfficialSite.playerSearch.query, "検索語を URL パラメータで渡さない")
    }

    func testIDURLsAcceptOnlyNumericIDs() {
        XCTAssertEqual(OfficialSite.athlete(id: "12345")?.absoluteString, "https://result.swim.or.jp/athletes/12345")
        XCTAssertEqual(OfficialSite.tournament(id: "6789")?.absoluteString, "https://result.swim.or.jp/tournament/6789")
        XCTAssertNil(OfficialSite.athlete(id: ""))
        XCTAssertNil(OfficialSite.athlete(id: "../admin"))
        XCTAssertNil(OfficialSite.athlete(id: "山田"))
        XCTAssertNil(OfficialSite.tournament(id: "12a"))
    }

    func testIsOfficialURL() {
        XCTAssertTrue(OfficialSite.isOfficialURL(URL(string: "https://result.swim.or.jp/tournament/4587")!))
        XCTAssertFalse(OfficialSite.isOfficialURL(URL(string: "http://result.swim.or.jp/")!))
        XCTAssertFalse(OfficialSite.isOfficialURL(URL(string: "https://result.swim.or.jp.evil.example/")!))
        XCTAssertFalse(OfficialSite.isOfficialURL(URL(string: "https://example.com/result.swim.or.jp")!))
    }

    func testPageKind() {
        func kind(_ s: String) -> OfficialSite.PageKind? { OfficialSite.pageKind(of: URL(string: s)!) }
        XCTAssertEqual(kind("https://result.swim.or.jp/"), .tournamentList)
        XCTAssertEqual(kind("https://result.swim.or.jp/player-search"), .playerSearch)
        XCTAssertEqual(kind("https://result.swim.or.jp/tournament/list"), .tournamentList)
        XCTAssertEqual(kind("https://result.swim.or.jp/tournament/4587"), .tournament)
        XCTAssertEqual(kind("https://result.swim.or.jp/athletes/424848"), .athlete)
        XCTAssertEqual(kind("https://result.swim.or.jp/tournament/4587/heats/genders/1/swimming_styles/1/distances/2/classes/1/race_divisions/2/heats/1"), .raceResult)
        XCTAssertEqual(kind("https://result.swim.or.jp/about"), .other)
        XCTAssertNil(kind("https://example.com/"))
    }

    func testFavoriteLinkRejectsNonOfficialURL() {
        let now = Date()
        XCTAssertNil(FavoriteLink(title: "x", url: URL(string: "https://example.com/")!, createdAt: now))
        let fav = FavoriteLink(title: "  第1回  大会 ", url: URL(string: "https://result.swim.or.jp/tournament/4587")!, createdAt: now)
        XCTAssertEqual(fav?.title, "第1回 大会")
        XCTAssertEqual(fav?.kind, .tournament)
        let untitled = FavoriteLink(title: "   ", url: URL(string: "https://result.swim.or.jp/athletes/1")!, createdAt: now)
        XCTAssertEqual(untitled?.title, "https://result.swim.or.jp/athletes/1")
    }
}
