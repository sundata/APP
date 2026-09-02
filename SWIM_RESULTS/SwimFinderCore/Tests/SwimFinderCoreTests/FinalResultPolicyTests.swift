import XCTest
@testable import SwimFinderCore

final class FinalResultPolicyTests: XCTestCase {
    private func result(_ id: String, round: String, time: String = "1:00.00") -> SwimResult {
        SwimResult(id: id, meetID: "800001", meetName: "大会", playerID: "900001", playerName: "架空 太郎", affiliation: nil,
                   eventName: "男子 100m 自由形", distance: "100m", style: "自由形", gender: "男子",
                   roundLabel: round, rank: "1", time: time, remark: nil, officialURL: nil)
    }

    func testRaceRoundClassification() {
        XCTAssertEqual(RaceRound(officialLabel: "決勝(A-決勝)"), .final)
        XCTAssertEqual(RaceRound(officialLabel: "決勝"), .final)
        XCTAssertEqual(RaceRound(officialLabel: "タイム決勝"), .timedFinal)
        XCTAssertEqual(RaceRound(officialLabel: "準決勝1組目"), .semifinal)
        XCTAssertEqual(RaceRound(officialLabel: "予選11組目"), .preliminary)
        XCTAssertEqual(RaceRound(officialLabel: "予選ランキング"), .preliminary)
        XCTAssertEqual(RaceRound(officialLabel: "最終順位"), .officialFinalStanding)
        XCTAssertEqual(RaceRound(officialLabel: "謎のラウンド"), .unknown("謎のラウンド"))
        XCTAssertEqual(RaceRound(officialLabel: ""), .unknown(""))
    }

    func testFinalPreferredOverTimedFinalAndPrelim() {
        let selection = FinalResultPolicy.select(from: [
            result("p", round: "予選3組目"),
            result("t", round: "タイム決勝"),
            result("f", round: "決勝(A-決勝)"),
        ])
        guard case .confirmed(let round, let results) = selection else { return XCTFail("expected confirmed") }
        XCTAssertEqual(round, .final)
        XCTAssertEqual(results.map(\.id), ["f"])
        XCTAssertEqual(FinalResultPolicy.label(for: selection), "決勝")
    }

    func testTimedFinalUsedWhenNoFinal() {
        let selection = FinalResultPolicy.select(from: [result("p", round: "予選1組目"), result("t", round: "タイム決勝")])
        guard case .confirmed(let round, let results) = selection else { return XCTFail("expected confirmed") }
        XCTAssertEqual(round, .timedFinal)
        XCTAssertEqual(results.map(\.id), ["t"])
        XCTAssertEqual(FinalResultPolicy.label(for: selection), "タイム決勝")
    }

    func testUnknownRoundIsNeverTreatedAsFinal() {
        XCTAssertFalse(RaceRound.unknown("結果").isFinalStanding)
        let selection = FinalResultPolicy.select(from: [result("u", round: "結果"), result("p", round: "予選2組目")])
        guard case .unverified(let available) = selection else { return XCTFail("expected unverified") }
        XCTAssertEqual(available.count, 2)
        XCTAssertFalse(selection.isConfirmedFinal)
        XCTAssertTrue(FinalResultPolicy.label(for: selection).contains("公式ページ"))
    }

    func testPrelimOnlyIsUnverified() {
        let selection = FinalResultPolicy.select(from: [result("p", round: "予選ランキング")])
        XCTAssertFalse(selection.isConfirmedFinal)
    }

    func testEmpty() {
        XCTAssertEqual(FinalResultPolicy.select(from: []), .empty)
    }

    func testSortedForDisplayIsStable() {
        let sorted = FinalResultPolicy.sortedForDisplay([
            result("p1", round: "予選1組目"), result("u", round: "?"), result("t", round: "タイム決勝"),
            result("p2", round: "予選2組目"), result("f", round: "決勝"),
        ])
        XCTAssertEqual(sorted.map(\.id), ["f", "t", "p1", "p2", "u"])
    }

    func testSwimTimeParsing() {
        XCTAssertEqual(SwimTime.seconds(from: "51.79"), 51.79)
        XCTAssertEqual(SwimTime.seconds(from: "1:02.34")!, 62.34, accuracy: 0.0001)
        XCTAssertEqual(SwimTime.seconds(from: "0:00.09")!, 0.09, accuracy: 0.0001)
        XCTAssertNil(SwimTime.seconds(from: ""))
        XCTAssertNil(SwimTime.seconds(from: "DSQ"))
        XCTAssertNil(SwimTime.seconds(from: "1::02"))
    }
}
