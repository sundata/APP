import Foundation

/// 「最終結果」の判定規則。
/// 1. 公式に「決勝」と明示された結果
/// 2. 「タイム決勝」
/// 3. 「最終順位」「総合結果」
/// 4. どれも確認できなければ「最終結果」と呼ばず、公式ページでの確認を促す
public enum FinalResultPolicy {
    public enum Selection: Sendable, Hashable {
        /// 決勝相当の結果が確認できた
        case confirmed(round: RaceRound, results: [SwimResult])
        /// 決勝相当が確認できないため、最終結果とは表示しない
        case unverified(available: [SwimResult])
        case empty

        public var isConfirmedFinal: Bool {
            if case .confirmed = self { return true }
            return false
        }
    }

    /// 同一種目の結果群から、最終結果として表示すべきものを選ぶ。
    public static func select(from results: [SwimResult]) -> Selection {
        guard !results.isEmpty else { return .empty }
        let finals = results.filter { $0.round.isFinalStanding }
        guard let best = finals.map(\.round).min(by: { $0.priority < $1.priority }) else {
            return .unverified(available: results)
        }
        return .confirmed(round: best, results: finals.filter { $0.round == best })
    }

    /// 一覧表示用の並び替え：決勝 → タイム決勝 → 最終順位 → 準決勝 → 予選 → 不明。同順位内は元の順序を保つ。
    public static func sortedForDisplay(_ results: [SwimResult]) -> [SwimResult] {
        results.enumerated()
            .sorted { lhs, rhs in
                let lp = lhs.element.round.priority
                let rp = rhs.element.round.priority
                return lp != rp ? lp < rp : lhs.offset < rhs.offset
            }
            .map(\.element)
    }

    /// 選択結果に付ける日本語ラベル。
    public static func label(for selection: Selection) -> String {
        switch selection {
        case .confirmed(let round, _):
            switch round {
            case .final: return "決勝"
            case .timedFinal: return "タイム決勝"
            case .officialFinalStanding: return "最終順位"
            default: return "最終結果"
            }
        case .unverified:
            return "最終結果は未確認です。公式ページで確認してください。"
        case .empty:
            return "結果がありません"
        }
    }
}
