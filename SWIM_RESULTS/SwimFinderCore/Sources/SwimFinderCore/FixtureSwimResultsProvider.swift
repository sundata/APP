import Foundation

/// テスト・プレビュー用のフィクスチャ実装。実在の選手・記録は含まない（架空データのみ）。
/// 通信は行わない。エラー再現のため `failure` を設定できる。
public actor FixtureSwimResultsProvider: SwimResultsProviding {
    public var players: [PlayerSummary]
    public var meets: [MeetSummary]
    public var results: [SwimResult]
    public var failure: SwimResultsError?
    /// 応答遅延（キャンセルのテストに使う）
    public var latency: Duration
    private(set) public var callCount = 0

    public init(players: [PlayerSummary] = Fixtures.players,
                meets: [MeetSummary] = Fixtures.meets,
                results: [SwimResult] = Fixtures.results,
                failure: SwimResultsError? = nil,
                latency: Duration = .zero) {
        self.players = players
        self.meets = meets
        self.results = results
        self.failure = failure
        self.latency = latency
    }

    public func setFailure(_ failure: SwimResultsError?) { self.failure = failure }

    private func prepare() async throws {
        callCount += 1
        if latency > .zero {
            do { try await Task.sleep(for: latency) } catch { throw SwimResultsError.cancelled }
        }
        if Task.isCancelled { throw SwimResultsError.cancelled }
        if let failure { throw failure }
    }

    public func searchPlayers(query: PlayerQuery) async throws -> [PlayerSummary] {
        try await prepare()
        let needle = query.name.replacingOccurrences(of: " ", with: "")
        let affiliation = query.affiliation.replacingOccurrences(of: " ", with: "")
        guard !needle.isEmpty || !affiliation.isEmpty else { return [] }
        return players.filter {
            (needle.isEmpty || $0.displayName.replacingOccurrences(of: " ", with: "").contains(needle)) &&
            (affiliation.isEmpty || ($0.affiliation ?? "").replacingOccurrences(of: " ", with: "").contains(affiliation))
        }
    }

    public func playerResults(playerID: String) async throws -> [SwimResult] {
        try await prepare()
        return results.filter { $0.playerID == playerID }
    }

    public func playerProfile(playerID: String) async throws -> PlayerProfile {
        try await prepare()
        let matching = players.filter { $0.athleteID == playerID || $0.id == playerID }
        let player = matching.first ?? players[0]
        return PlayerProfile(displayName: player.displayName, romanName: "TARO KAKU",
                             maskedCode: "****001",
                             affiliations: matching.compactMap(\.affiliation),
                             memberGroup: player.memberGroup, schoolClass: player.schoolClass,
                             gender: player.gender, updatedAt: "2026/04/01")
    }

    public func searchMeets(query: MeetQuery) async throws -> [MeetSummary] {
        try await prepare()
        let needle = query.name
        guard !needle.isEmpty else { return [] }
        return meets.filter { meet in
            guard meet.name.contains(needle) else { return false }
            if let year = query.fiscalYear, !(meet.period?.hasPrefix(String(year)) ?? true) { return false }
            if let waterwayCode = query.waterwayCode, meet.course != (waterwayCode == 1 ? "長水路" : "短水路") { return false }
            let statusNames = [0: "中止", 1: "開催前", 2: "エントリー済み", 3: "開催中", 4: "大会終了", 5: "記録確定", 6: "延期", 7: "記録未登録"]
            if let statusCode = query.statusCode, meet.status != statusNames[statusCode] { return false }
            if let prefectureCode = query.prefectureCode, prefectureCode == 12, meet.organizer != "千葉" { return false }
            return true
        }
    }

    public func meetResults(meetID: String, filter: ResultFilter) async throws -> [SwimResult] {
        try await prepare()
        return results.filter { result in
            guard result.meetID == meetID else { return false }
            if let g = filter.gender, result.gender != g { return false }
            if let s = filter.style, result.style != s { return false }
            if let d = filter.distance, result.distance != d { return false }
            return true
        }
    }

    public func meetEvents(meetID: String) async throws -> [MeetEvent] {
        try await prepare()
        return [MeetEvent(meetID: meetID, date: "2026-04-04", genderCode: 1, gender: "男子", styleCode: 1, style: "自由形", distanceCode: 3, distance: "100m", classCode: 0, divisionCode: 4, division: "決勝")]
    }

    public func eventResults(event: MeetEvent) async throws -> [SwimResult] {
        try await prepare()
        return results.filter { $0.meetID == event.meetID }
    }

    /// 架空のフィクスチャ。
    public enum Fixtures {
        public static let players: [PlayerSummary] = [
            PlayerSummary(id: "900001", displayName: "架空 太郎", affiliation: "サンプルSC", memberGroup: "東京", schoolClass: "高校", gender: "男子"),
            PlayerSummary(id: "900002", displayName: "架空 太郎", affiliation: "テスト大学", memberGroup: "大阪", schoolClass: "大学", gender: "男子"),
            PlayerSummary(id: "900003", displayName: "見本 花子", affiliation: "サンプルSC", memberGroup: "東京", schoolClass: "中学", gender: "女子"),
        ]

        public static let meets: [MeetSummary] = [
            MeetSummary(id: "800001", name: "サンプル市民水泳大会", period: "2026年04月04日(土) ~ 2026年04月05日(日)", venue: "サンプル市民プール", organizer: "千葉", course: "長水路", status: "記録確定"),
            MeetSummary(id: "800002", name: "サンプル市民水泳大会", period: "2025年04月05日(土) ~ 2025年04月06日(日)", venue: "サンプル市民プール", organizer: "千葉", course: "長水路", status: "記録確定"),
        ]

        public static let results: [SwimResult] = [
            SwimResult(id: "r1", meetID: "800001", meetName: "サンプル市民水泳大会", resultDate: "2025-04-04", playerID: "900001", playerName: "架空 太郎", affiliation: "サンプルSC", eventName: "100m 自由形（長水路）", distance: "100m", style: "自由形", gender: "男子", roundLabel: "予選3組目", rank: "2", time: "52.10", remark: nil, officialURL: nil),
            SwimResult(id: "r2", meetID: "800001", meetName: "サンプル市民水泳大会", resultDate: "2026-04-05", playerID: "900001", playerName: "架空 太郎", affiliation: "サンプルSC", eventName: "100m 自由形（長水路）", distance: "100m", style: "自由形", gender: "男子", roundLabel: "決勝(A-決勝)", rank: "1", time: "51.79", remark: nil, officialURL: nil),
            SwimResult(id: "r3", meetID: "800001", meetName: "サンプル市民水泳大会", playerID: "900003", playerName: "見本 花子", affiliation: "サンプルSC", eventName: "女子 50m 背泳ぎ", distance: "50m", style: "背泳ぎ", gender: "女子", roundLabel: "タイム決勝", rank: "3", time: "31.20", remark: nil, officialURL: nil),
            SwimResult(id: "r4", meetID: "800002", meetName: "サンプル市民水泳大会", playerID: "900002", playerName: "架空 太郎", affiliation: "テスト大学", eventName: "男子 200m 個人メドレー", distance: "200m", style: "個人メドレー", gender: "男子", roundLabel: "予選1組目", rank: "-", time: "", remark: "DSQ", officialURL: nil),
        ]
    }
}
