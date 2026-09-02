import Foundation

/// Mode B の「公式サイトを開く」操作を組み立てる純粋ロジック。
/// アプリは検索語をクリップボードへコピーし、公式検索ページを Safari 表示で開く。
public enum OfficialSiteLaunch {
    public struct Plan: Sendable, Hashable {
        /// 開く公式 URL
        public let url: URL
        /// クリップボードへコピーする検索語（正規化済み）。空なら何もコピーしない。
        public let clipboardText: String
        /// 履歴に記録する項目（記録しない場合は nil）
        public let historyItem: RecentSearch?
        /// 画面に出す案内文
        public let guidance: String
    }

    public enum Failure: Error, Sendable, Hashable {
        case emptyQuery
        case tooShort(minimum: Int)

        public var userMessage: String {
            switch self {
            case .emptyQuery:
                return "検索する名前を入力してください。"
            case .tooShort(let minimum):
                return "\(minimum)文字以上で入力してください。"
            }
        }
    }

    public static func player(_ query: PlayerQuery, now: Date) -> Result<Plan, Failure> {
        switch validate(query.rawName) {
        case .failure(let failure): return .failure(failure)
        case .success(let normalized):
            let item = RecentSearch(kind: .player, rawQuery: query.rawName, officialURL: OfficialSite.playerSearch, searchedAt: now)
            return .success(Plan(
                url: OfficialSite.playerSearch,
                clipboardText: normalized,
                historyItem: item,
                guidance: "「\(normalized)」をコピーしました。公式サイトの「選手名」欄に貼り付けて検索してください。"
            ))
        }
    }

    public static func meet(_ query: MeetQuery, now: Date) -> Result<Plan, Failure> {
        switch validate(query.rawName) {
        case .failure(let failure): return .failure(failure)
        case .success(let normalized):
            let item = RecentSearch(kind: .meet, rawQuery: query.rawName, fiscalYear: query.fiscalYear, officialURL: OfficialSite.tournamentList, searchedAt: now)
            var guidance = "「\(normalized)」をコピーしました。公式サイトの「大会名」欄に貼り付けて検索してください。"
            if let year = query.fiscalYear {
                guidance += "年度は「\(year)年度」を選択してください。"
            }
            return .success(Plan(
                url: OfficialSite.tournamentList,
                clipboardText: normalized,
                historyItem: item,
                guidance: guidance
            ))
        }
    }

    /// 履歴やお気に入りからの再表示。クリップボードには何もコピーしない。
    public static func reopen(_ url: URL) -> Plan? {
        guard OfficialSite.isOfficialURL(url) else { return nil }
        return Plan(url: url, clipboardText: "", historyItem: nil, guidance: "公式ページで最新情報を確認してください。")
    }

    private static func validate(_ raw: String) -> Result<String, Failure> {
        let normalized = QueryNormalizer.normalize(raw)
        if normalized.isEmpty { return .failure(.emptyQuery) }
        if !QueryNormalizer.isSearchable(normalized) { return .failure(.tooShort(minimum: QueryNormalizer.minimumLength)) }
        return .success(normalized)
    }
}
