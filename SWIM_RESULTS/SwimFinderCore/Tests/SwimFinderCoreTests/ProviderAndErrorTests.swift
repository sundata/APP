import XCTest
@testable import SwimFinderCore

final class ProviderAndErrorTests: XCTestCase {
    // MARK: 同姓同名・同名大会・0 件

    func testSameNamePlayersAreAllReturnedAndDistinguishable() async throws {
        let provider = FixtureSwimResultsProvider()
        let players = try await provider.searchPlayers(query: PlayerQuery(rawName: "架空 太郎"))
        XCTAssertEqual(players.count, 2, "同姓同名は自動確定せず全件返す")
        XCTAssertNotEqual(players[0].affiliation, players[1].affiliation)
        XCTAssertEqual(Set(players.map(\.id)).count, 2)
    }

    func testSameNameMeetsDistinguishedByYear() async throws {
        let provider = FixtureSwimResultsProvider()
        let all = try await provider.searchMeets(query: MeetQuery(rawName: "サンプル市民水泳大会"))
        XCTAssertEqual(all.count, 2)
        let only2026 = try await provider.searchMeets(query: MeetQuery(rawName: "サンプル市民水泳大会", fiscalYear: 2026))
        XCTAssertEqual(only2026.map(\.id), ["800001"])
    }

    func testZeroResultsIsEmptyArrayNotError() async throws {
        let provider = FixtureSwimResultsProvider()
        let players = try await provider.searchPlayers(query: PlayerQuery(rawName: "存在しない名前"))
        XCTAssertEqual(players, [])
    }

    func testDSQResultKeepsOfficialRemarkAndNoSeconds() async throws {
        let provider = FixtureSwimResultsProvider()
        let results = try await provider.playerResults(playerID: "900002")
        XCTAssertEqual(results.first?.remark, "DSQ")
        XCTAssertNil(results.first?.seconds)
    }

    // MARK: エラー分類

    func testNetworkFailuresPropagateAsErrorsNotEmpty() async {
        let cases: [SwimResultsError] = [.offline, .dnsFailure, .timeout, .rateLimited(retryAfterSeconds: 30), .serverError(status: 503), .malformedResponse]
        for failure in cases {
            let provider = FixtureSwimResultsProvider(failure: failure)
            do {
                _ = try await provider.searchPlayers(query: PlayerQuery(rawName: "架空"))
                XCTFail("expected \(failure) to throw")
            } catch let error as SwimResultsError {
                XCTAssertEqual(error, failure)
                XCTAssertFalse(error.userMessage.contains("該当"), "失敗を「該当なし」と表現しない")
            } catch {
                XCTFail("unexpected \(error)")
            }
        }
    }

    func testHTTPStatusMapping() {
        XCTAssertNil(SwimResultsError.from(httpStatus: 200))
        XCTAssertEqual(SwimResultsError.from(httpStatus: 429, retryAfter: 10), .rateLimited(retryAfterSeconds: 10))
        XCTAssertEqual(SwimResultsError.from(httpStatus: 503), .serverError(status: 503))
        XCTAssertTrue(SwimResultsError.rateLimited(retryAfterSeconds: nil).isRetryable)
        XCTAssertFalse(SwimResultsError.specChangeSuspected(detail: "x").isRetryable)
        XCTAssertTrue(SwimResultsError.rateLimited(retryAfterSeconds: 30).userMessage.contains("30"))
    }

    func testDisabledProviderAlwaysNotPermitted() async {
        let provider = DisabledSwimResultsProvider()
        do {
            _ = try await provider.searchMeets(query: MeetQuery(rawName: "大会"))
            XCTFail("expected notPermitted")
        } catch {
            XCTAssertEqual(error as? SwimResultsError, .notPermitted)
        }
    }

    // MARK: キャンセル・デバウンス

    func testCancellationThrowsCancelled() async {
        let provider = FixtureSwimResultsProvider(latency: .seconds(5))
        let task = Task { try await provider.searchPlayers(query: PlayerQuery(rawName: "架空")) }
        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("expected cancellation")
        } catch {
            XCTAssertEqual(error as? SwimResultsError, .cancelled)
        }
    }

    func testDebouncerFiresOnlyLastOperation() async {
        let debouncer = SearchDebouncer(delay: .milliseconds(80))
        let counter = Counter()
        for i in 1...5 {
            await debouncer.schedule { await counter.record(i) }
            try? await Task.sleep(for: .milliseconds(10))
        }
        try? await Task.sleep(for: .milliseconds(300))
        let values = await counter.values
        XCTAssertEqual(values, [5])
        let fired = await debouncer.firedCount
        XCTAssertEqual(fired, 1)
    }

    func testDebouncerCancel() async {
        let debouncer = SearchDebouncer(delay: .milliseconds(50))
        let counter = Counter()
        await debouncer.schedule { await counter.record(1) }
        await debouncer.cancel()
        try? await Task.sleep(for: .milliseconds(200))
        let values = await counter.values
        XCTAssertEqual(values, [])
    }

    // MARK: キャッシュ日時

    func testFetchedStaleness() {
        let fetched = Fetched(value: 1, fetchedAt: Date(timeIntervalSince1970: 0))
        XCTAssertFalse(fetched.isStale(now: Date(timeIntervalSince1970: 100), maxAge: 3600))
        XCTAssertTrue(fetched.isStale(now: Date(timeIntervalSince1970: 4000), maxAge: 3600))
    }

    // MARK: レスポンス検証（仕様変更を 0 件扱いにしない）

    private let contract = ResponseValidator.ListContract(itemsKey: "data", requiredKeys: ["id", "name"])

    func testValidatorAcceptsEmptyListAsZeroResults() throws {
        let items = try ResponseValidator.validateList(Data(#"{"data":[]}"#.utf8), contract: contract)
        XCTAssertEqual(items.count, 0)
    }

    func testValidatorAcceptsWellFormedItems() throws {
        let items = try ResponseValidator.validateList(Data(#"{"data":[{"id":1,"name":"A","extra":true}]}"#.utf8), contract: contract)
        XCTAssertEqual(items.count, 1)
    }

    func testValidatorRejectsBrokenJSON() {
        XCTAssertThrowsError(try ResponseValidator.validateList(Data("<html>".utf8), contract: contract)) { error in
            XCTAssertEqual(error as? SwimResultsError, .malformedResponse)
        }
    }

    func testValidatorFlagsSpecChangeInsteadOfZeroResults() {
        let samples = [
            #"{"items":[]}"#,
            #"{"data":null}"#,
            #"{"data":{"id":1}}"#,
            #"{"data":[{"id":1}]}"#,
            #"[]"#,
        ]
        for sample in samples {
            XCTAssertThrowsError(try ResponseValidator.validateList(Data(sample.utf8), contract: contract), sample) { error in
                guard case .specChangeSuspected = error as? SwimResultsError else {
                    return XCTFail("expected specChangeSuspected for \(sample), got \(error)")
                }
            }
        }
    }
}

private actor Counter {
    var values: [Int] = []
    func record(_ value: Int) { values.append(value) }
}
