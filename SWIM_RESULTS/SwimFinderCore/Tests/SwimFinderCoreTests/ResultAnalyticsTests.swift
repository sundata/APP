import XCTest
@testable import SwimFinderCore

final class ResultAnalyticsTests: XCTestCase {
    private func result(_ id: String, event: String, time: String, remark: String? = nil, date: String = "2026-01-01") -> SwimResult {
        SwimResult(id: id, meetID: "m", meetName: "大会", resultDate: date, playerID: "p", playerName: "選手", affiliation: nil, eventName: event, distance: "100m", style: "自由形", gender: "男子", roundLabel: "決勝", rank: "1", time: time, remark: remark, officialURL: nil)
    }

    func testLongAndShortCourseNeverShareAGroup() {
        let groups = ResultAnalytics.groupedPerformances([
            result("l", event: "100m 自由形（長水路）", time: "55.00"),
            result("s", event: "100m 自由形（短水路）", time: "53.00")
        ])
        XCTAssertEqual(groups.count, 2)
        XCTAssertEqual(Set(groups.keys.map(\.course)), [.long, .short])
    }

    func testDisqualifiedAndEmptyRecordsCannotBecomeBest() {
        let valid = result("valid", event: "100m 自由形（長水路）", time: "55.00")
        let dsq = result("dsq", event: "100m 自由形（長水路）", time: "50.00", remark: "DSQ")
        let empty = result("empty", event: "100m 自由形（長水路）", time: "")
        XCTAssertEqual(ResultAnalytics.personalBest(in: [dsq, empty, valid])?.id, "valid")
    }

    func testChronologicalOrderUsesDateThenStableID() {
        let later = result("b", event: "100m 自由形（長水路）", time: "54", date: "2026-02-01")
        let earlier = result("a", event: "100m 自由形（長水路）", time: "55", date: "2026-01-01")
        XCTAssertEqual(ResultAnalytics.chronological([later, earlier]).map(\.id), ["a", "b"])
    }

    func testLatestDeltaAndConsecutiveImprovement() {
        let first = result("a", event: "100m 自由形（長水路）", time: "56", date: "2026-01-01")
        let second = result("b", event: "100m 自由形（長水路）", time: "55", date: "2026-02-01")
        let third = result("c", event: "100m 自由形（長水路）", time: "54.5", date: "2026-03-01")
        XCTAssertEqual(ResultAnalytics.latestDelta(in: [third, first, second]), -0.5)
        XCTAssertEqual(ResultAnalytics.consecutiveImprovementCount(in: [third, first, second]), 2)
        XCTAssertTrue(ResultAnalytics.isAnnualBest(third, among: [first, second, third]))
    }

    func testConsecutiveImprovementStopsWhenTimeGetsSlower() {
        let first = result("a", event: "100m 自由形（長水路）", time: "56", date: "2026-01-01")
        let second = result("b", event: "100m 自由形（長水路）", time: "55", date: "2026-02-01")
        let third = result("c", event: "100m 自由形（長水路）", time: "55.2", date: "2026-03-01")
        XCTAssertEqual(ResultAnalytics.consecutiveImprovementCount(in: [first, second, third]), 0)
    }
}
