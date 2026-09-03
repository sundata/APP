import Foundation
import SwimFinderCore

/// 公式 API の短時間キャッシュと、一時的な通信障害の自動再試行を担当する。
actor ReliableSwimResultsProvider: SwimResultsProviding {
    private struct Entry<Value: Sendable>: Sendable {
        let value: Value
        let date: Date
    }

    private let upstream: SwimResultsProviding
    private let maxAge: TimeInterval
    private var players: [PlayerQuery: Entry<[PlayerSummary]>] = [:]
    private var profiles: [String: Entry<PlayerProfile>] = [:]
    private var playerRecords: [String: Entry<[SwimResult]>] = [:]
    private var meets: [MeetQuery: Entry<[MeetSummary]>] = [:]
    private var events: [String: Entry<[MeetEvent]>] = [:]
    private var eventRecords: [MeetEvent: Entry<[SwimResult]>] = [:]

    init(upstream: SwimResultsProviding, maxAge: TimeInterval = 300) {
        self.upstream = upstream
        self.maxAge = maxAge
    }

    func searchPlayers(query: PlayerQuery) async throws -> [PlayerSummary] {
        let result = try await fetch(cached: players[query]) { try await upstream.searchPlayers(query: query) }
        if result.shouldStore { players[query] = Entry(value: result.value, date: Date()) }
        return result.value
    }

    func playerProfile(playerID: String) async throws -> PlayerProfile {
        let result = try await fetch(cached: profiles[playerID]) { try await upstream.playerProfile(playerID: playerID) }
        if result.shouldStore { profiles[playerID] = Entry(value: result.value, date: Date()) }
        return result.value
    }

    func playerResults(playerID: String) async throws -> [SwimResult] {
        let result = try await fetch(cached: playerRecords[playerID]) { try await upstream.playerResults(playerID: playerID) }
        if result.shouldStore { playerRecords[playerID] = Entry(value: result.value, date: Date()) }
        return result.value
    }

    func searchMeets(query: MeetQuery) async throws -> [MeetSummary] {
        let result = try await fetch(cached: meets[query]) { try await upstream.searchMeets(query: query) }
        if result.shouldStore { meets[query] = Entry(value: result.value, date: Date()) }
        return result.value
    }

    func meetResults(meetID: String, filter: ResultFilter) async throws -> [SwimResult] {
        try await withRetry { try await upstream.meetResults(meetID: meetID, filter: filter) }
    }

    func meetEvents(meetID: String) async throws -> [MeetEvent] {
        let result = try await fetch(cached: events[meetID]) { try await upstream.meetEvents(meetID: meetID) }
        if result.shouldStore { events[meetID] = Entry(value: result.value, date: Date()) }
        return result.value
    }

    func eventResults(event: MeetEvent) async throws -> [SwimResult] {
        let result = try await fetch(cached: eventRecords[event]) { try await upstream.eventResults(event: event) }
        if result.shouldStore { eventRecords[event] = Entry(value: result.value, date: Date()) }
        return result.value
    }

    private func fetch<Value: Sendable>(cached entry: Entry<Value>?, operation: () async throws -> Value) async throws -> (value: Value, shouldStore: Bool) {
        let now = Date()
        if let entry, now.timeIntervalSince(entry.date) <= maxAge { return (entry.value, false) }
        let fallback = entry?.value
        do {
            let value = try await withRetry(operation)
            return (value, true)
        } catch {
            if let fallback { return (fallback, false) }
            throw error
        }
    }

    private func withRetry<Value: Sendable>(_ operation: () async throws -> Value) async throws -> Value {
        var lastError: Error?
        for attempt in 0..<3 {
            do { return try await operation() }
            catch let error as SwimResultsError {
                lastError = error
                guard error.isRetryable, attempt < 2 else { throw error }
                try await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
            } catch {
                throw error
            }
        }
        throw lastError ?? SwimResultsError.offline
    }
}
