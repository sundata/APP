import Foundation

/// 検索語の正規化。原文は呼び出し側で保持し、送信・比較には正規化後の値を使う。
public enum QueryNormalizer {
    /// 送信に必要な最小文字数（空白を除く）。
    public static let minimumLength = 2

    /// 前後の空白を除き、全角・連続空白を半角スペース 1 つに揃える。
    /// 文字そのもの（漢字・かな・カナ・英字）は変換しない。
    public static func normalize(_ raw: String) -> String {
        let unified = raw.map { character -> Character in
            character.isWhitespace || character == "\u{3000}" ? " " : character
        }
        return String(unified)
            .split(separator: " ", omittingEmptySubsequences: true)
            .joined(separator: " ")
    }

    /// 空白を除いた文字数。
    public static func significantLength(of raw: String) -> Int {
        normalize(raw).filter { !$0.isWhitespace }.count
    }

    /// 検索を送信してよいか（2 文字未満は送信しない）。
    public static func isSearchable(_ raw: String) -> Bool {
        significantLength(of: raw) >= minimumLength
    }

    /// 「姓 名」を分割する。空白がなければ姓のみとして扱う。
    public static func splitName(_ raw: String) -> (family: String, given: String?) {
        let parts = normalize(raw).split(separator: " ", maxSplits: 1).map(String.init)
        guard let family = parts.first else { return ("", nil) }
        return (family, parts.count > 1 ? parts[1] : nil)
    }
}
