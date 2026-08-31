import Foundation

/// 今日の気分。評価や診断ではなく、今の状態を短く残すための選択肢。
public enum DailyMood: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case energized
    case calm
    case fluttering
    case tired
    case cloudy

    public var id: String { rawValue }

    public var emoji: String {
        switch self {
        case .energized: return "☀️"
        case .calm: return "🌿"
        case .fluttering: return "💗"
        case .tired: return "🌙"
        case .cloudy: return "☁️"
        }
    }

    public var japaneseName: String {
        switch self {
        case .energized: return "元気"
        case .calm: return "穏やか"
        case .fluttering: return "ときめき"
        case .tired: return "おつかれ"
        case .cloudy: return "もやもや"
        }
    }

    public var gentleMessage: String {
        switch self {
        case .energized: return "その軽やかさを、好きなことに少し分けてみて。"
        case .calm: return "静かな心地よさを、今日は丁寧に味わって。"
        case .fluttering: return "小さなときめきを見逃さない一日に。"
        case .tired: return "できたことをひとつ数えたら、休むのも立派な選択。"
        case .cloudy: return "答えを急がなくて大丈夫。深呼吸できれば十分です。"
        }
    }
}

/// 占いに添える、毎日の会話や身支度に使いやすい小さなヒント。
public struct DailyLifestyleContent: Hashable, Sendable {
    public let loveKeyword: String
    public let styleTip: String
    public let conversationStarter: String
    public let nightQuestion: String

    public init(fortune: DailyFortune) {
        let seed = StableSeed("\(fortune.date)|\(fortune.zodiac.rawValue)|lifestyle-v1")
        loveKeyword = Self.loveKeywords.element(for: seed.derived("love-keyword"))
        styleTip = Self.styleTips.element(for: seed.derived("style"))
        conversationStarter = Self.conversationStarters.element(for: seed.derived("conversation"))
        nightQuestion = Self.nightQuestions.element(for: seed.derived("night"))
    }

    private static let loveKeywords = [
        "素直なひと言", "目が合った瞬間", "ゆっくり返信", "さりげない気づかい",
        "笑顔の余韻", "共通の好き", "いつもより一歩", "自分らしい距離感"
    ]

    private static let styleTips = [
        "耳元に小さなきらめきを足して、横顔を味方に。",
        "やわらかな素材をひとつ選んで、動きに余白を。",
        "リップかネイルにラッキーカラーを少しだけ。",
        "いつもの服に細いアクセサリーを重ねてみて。",
        "髪の分け目を変えて、気分にも新しい風を。",
        "お気に入りの香りを、近づいたときだけ分かるくらいに。"
    ]

    private static let conversationStarters = [
        "最近ちょっと嬉しかったこと、ある？",
        "今いちばん行ってみたい場所はどこ？",
        "今日の気分を色にすると何色？",
        "最近見つけた小さなお気に入りは？",
        "休みが一日増えたら、何をしたい？",
        "今リピートしている曲、教えて。"
    ]

    private static let nightQuestions = [
        "今日、自分にやさしくできた瞬間は？",
        "心が少し動いた出来事はあった？",
        "明日の自分にひとつ渡したい言葉は？",
        "今日いちばん安心した瞬間は？",
        "もう一度味わいたい小さな出来事は？"
    ]
}
