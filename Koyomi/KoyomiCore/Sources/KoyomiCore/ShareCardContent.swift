import Foundation

/// シェアカードに載せる情報だけを持つ値。
/// ニックネーム・生年月日・位置情報は構造上入らないようにしている。
public struct ShareCardContent: Hashable, Sendable {
    public let dateText: String
    public let zodiacName: String
    public let headline: String
    public let shortMessage: String
    public let luckyColor: LuckyColor
    public let brandName: String
    public let disclaimer: String

    public init(fortune: DailyFortune, dateText: String, brandName: String = "Koyomi") {
        self.dateText = dateText
        self.zodiacName = fortune.zodiac.japaneseName
        self.headline = fortune.headline
        self.shortMessage = Self.shortMessage(from: fortune.overall)
        self.luckyColor = fortune.luckyColor
        self.brandName = brandName
        self.disclaimer = fortune.disclaimer
    }

    /// 総合運の最初の一文だけを使う（カードに収まる長さにする）。
    static func shortMessage(from overall: String) -> String {
        let sentences = overall.split(separator: "。", omittingEmptySubsequences: true)
        guard let first = sentences.first else { return overall }
        return "\(first)。"
    }
}
