import Foundation

/// 日本水泳連盟 結果サイト（Results of Japan Swimming）の公開 URL。
/// アプリが開く URL はここで定義したものだけ。非公開 API の URL は定義しない。
public enum OfficialSite {
    public static let host = "result.swim.or.jp"
    public static let base = URL(string: "https://result.swim.or.jp/")!

    /// 選手検索（クエリパラメータは公式に非対応のため付けない）
    public static let playerSearch = URL(string: "https://result.swim.or.jp/player-search")!
    /// 大会検索（トップページと同一機能）
    public static let tournamentList = URL(string: "https://result.swim.or.jp/tournament/list")!

    /// 選手情報ページ。ID は公式が発行した数値 ID のみ受け付ける。
    public static func athlete(id: String) -> URL? {
        guard isOfficialID(id) else { return nil }
        return URL(string: "https://result.swim.or.jp/athletes/\(id)")
    }

    /// 大会詳細ページ。ID は公式が発行した数値 ID のみ受け付ける。
    public static func tournament(id: String) -> URL? {
        guard isOfficialID(id) else { return nil }
        return URL(string: "https://result.swim.or.jp/tournament/\(id)")
    }

    /// 公式 ID は数字のみ（氏名などから生成した ID は受け付けない）。
    public static func isOfficialID(_ id: String) -> Bool {
        !id.isEmpty && id.count <= 12 && id.allSatisfy(\.isNumber)
    }

    /// 公式結果サイトの URL か（https かつホスト一致）。
    public static func isOfficialURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https" && url.host?.lowercased() == host
    }

    /// 公式 URL の種類。お気に入り表示のアイコン・説明に使う。
    public enum PageKind: String, Sendable, Codable, CaseIterable {
        case playerSearch
        case tournamentList
        case athlete
        case tournament
        case raceResult
        case other
    }

    public static func pageKind(of url: URL) -> PageKind? {
        guard isOfficialURL(url) else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        switch parts.first {
        case "player-search":
            return .playerSearch
        case "athletes":
            return parts.count == 2 && isOfficialID(parts[1]) ? .athlete : .other
        case "tournament":
            if parts.count == 2, parts[1] == "list" { return .tournamentList }
            if parts.count == 2, isOfficialID(parts[1]) { return .tournament }
            if parts.count > 2, isOfficialID(parts[1]), parts[2] == "heats" { return .raceResult }
            return .other
        case nil:
            return .tournamentList
        default:
            return .other
        }
    }
}
