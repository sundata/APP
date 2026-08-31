import Foundation

/// コンテンツの安全基準。テストでコンテンツプール全体を検査する。
public enum ContentSafety {
    /// 断定的な約束や、占いで扱わない領域を示す語。
    public static let forbiddenTerms: [String] = [
        "絶対", "必ず当たる", "運命", "宿命",
        "死", "病気", "癌", "妊娠", "流産",
        "裏切", "事故", "災害", "地震",
        "投資", "儲か", "株価", "合格", "不合格",
        "痩せ", "ダイエット", "太っ",
        "治る", "診断", "薬を"
    ]

    /// 開発用のプレースホルダや日本語以外の混入を検出する語。
    public static let placeholderTerms: [String] = [
        "TODO", "TBD", "FIXME", "Lorem", "サンプル文", "ダミー"
    ]

    /// 文章が安全基準を満たしているか。
    public static func violations(in text: String) -> [String] {
        (forbiddenTerms + placeholderTerms).filter { text.contains($0) }
    }

    /// 検査対象となるすべてのユーザー向け文章。
    public static var allUserFacingContent: [String] {
        var texts: [String] = []
        texts += ContentLibrary.themes.flatMap { [$0.headline, $0.body] }
        texts += ContentLibrary.zodiacFlavors.values.flatMap { $0 }
        texts += ContentLibrary.weatherHints.values.flatMap { $0 }
        texts += ContentLibrary.seasonHints.values.flatMap { $0 }
        texts += ContentLibrary.loveTexts
        texts += ContentLibrary.workStudyTexts
        texts += ContentLibrary.beautyHealthTexts
        texts += ContentLibrary.socialTexts
        texts += ContentLibrary.dailyClosers
        texts += ContentLibrary.luckyItems
        texts += ContentLibrary.actions
        texts += ContentLibrary.luckyColors.map(\.name)
        texts += ContentLibrary.notificationMessages
        return texts
    }
}
