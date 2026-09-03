import Foundation

/// 結果データの取得契約。
/// 公開データ API の実通信実装と、テスト用フィクスチャ実装がこの契約に準拠する。
public protocol SwimResultsProviding: Sendable {
    func searchPlayers(query: PlayerQuery) async throws -> [PlayerSummary]
    func playerProfile(playerID: String) async throws -> PlayerProfile
    func playerResults(playerID: String) async throws -> [SwimResult]
    func searchMeets(query: MeetQuery) async throws -> [MeetSummary]
    func meetResults(meetID: String, filter: ResultFilter) async throws -> [SwimResult]
    func meetEvents(meetID: String) async throws -> [MeetEvent]
    func eventResults(event: MeetEvent) async throws -> [SwimResult]
}

/// 取得失敗の分類。「該当なし」と混同しないよう、0 件は成功（空配列）で表し、失敗は必ず throw する。
public enum SwimResultsError: Error, Sendable, Hashable {
    case offline
    case dnsFailure
    case timeout
    case rateLimited(retryAfterSeconds: Int?)
    case serverError(status: Int)
    case malformedResponse
    /// 必須項目が欠けるなど、公式サイトの仕様変更が疑われる状態
    case specChangeSuspected(detail: String)
    /// 利用許諾がないため機能を停止している
    case notPermitted
    case cancelled

    /// ユーザー向けの日本語メッセージ。失敗を「該当なし」と表現しない。
    public var userMessage: String {
        switch self {
        case .offline:
            return "インターネットに接続されていません。接続を確認してから再度お試しください。"
        case .dnsFailure:
            return "公式サイトに接続できませんでした。時間をおいて再度お試しください。"
        case .timeout:
            return "公式サイトの応答がありませんでした。時間をおいて再度お試しください。"
        case .rateLimited(let retry):
            if let retry {
                return "アクセスが集中しています。約\(retry)秒後に再度お試しください。"
            }
            return "アクセスが集中しています。しばらく待ってから再度お試しください。"
        case .serverError:
            return "公式サイト側で一時的な問題が発生しています。時間をおいて再度お試しください。"
        case .malformedResponse, .specChangeSuspected:
            return "公式サイトの表示形式が変わった可能性があります。公式ページで直接ご確認ください。"
        case .notPermitted:
            return "この機能は公式の利用許諾が確認できるまで無効になっています。公式ページでご確認ください。"
        case .cancelled:
            return "検索を中止しました。"
        }
    }

    /// 再試行が意味を持つか。
    public var isRetryable: Bool {
        switch self {
        case .offline, .dnsFailure, .timeout, .rateLimited, .serverError: return true
        case .malformedResponse, .specChangeSuspected, .notPermitted, .cancelled: return false
        }
    }

    /// HTTP ステータスからの分類（Mode A 実装用）。
    public static func from(httpStatus: Int, retryAfter: Int? = nil) -> SwimResultsError? {
        switch httpStatus {
        case 200..<300: return nil
        case 429: return .rateLimited(retryAfterSeconds: retryAfter)
        case 500...599: return .serverError(status: httpStatus)
        default: return .serverError(status: httpStatus)
        }
    }
}

/// 取得結果の鮮度。取得日時を必ず表示するために使う。
public struct Fetched<Value: Sendable>: Sendable {
    public let value: Value
    public let fetchedAt: Date

    public init(value: Value, fetchedAt: Date) {
        self.value = value
        self.fetchedAt = fetchedAt
    }

    /// `maxAge` を超えていれば再取得が必要。
    public func isStale(now: Date, maxAge: TimeInterval) -> Bool {
        now.timeIntervalSince(fetchedAt) > maxAge
    }
}

/// 通信機能を明示的に無効化する場合に、常に `.notPermitted` を返す実装。
public struct DisabledSwimResultsProvider: SwimResultsProviding {
    public init() {}
    public func searchPlayers(query: PlayerQuery) async throws -> [PlayerSummary] { throw SwimResultsError.notPermitted }
    public func playerProfile(playerID: String) async throws -> PlayerProfile { throw SwimResultsError.notPermitted }
    public func playerResults(playerID: String) async throws -> [SwimResult] { throw SwimResultsError.notPermitted }
    public func searchMeets(query: MeetQuery) async throws -> [MeetSummary] { throw SwimResultsError.notPermitted }
    public func meetResults(meetID: String, filter: ResultFilter) async throws -> [SwimResult] { throw SwimResultsError.notPermitted }
    public func meetEvents(meetID: String) async throws -> [MeetEvent] { throw SwimResultsError.notPermitted }
    public func eventResults(event: MeetEvent) async throws -> [SwimResult] { throw SwimResultsError.notPermitted }
}
