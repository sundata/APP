import Foundation

public struct DailyCharm: Hashable, Sendable {
    public let emoji: String
    public let name: String
    public let message: String
}

public struct DailyRitualTask: Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let symbolName: String
}

/// 数分で楽しめる、その日だけの小さな星願リストとコレクション。
public struct DailyRitualContent: Hashable, Sendable {
    public let tasks: [DailyRitualTask]
    public let charm: DailyCharm

    public init(fortune: DailyFortune) {
        let seed = StableSeed("\(fortune.date)|\(fortune.zodiac.rawValue)|ritual-v1")
        let start = seed.derived("tasks").index(upperBound: Self.taskPool.count)
        tasks = (0..<3).map { offset in
            let item = Self.taskPool.cyclicElement(at: start + offset * 5)
            return DailyRitualTask(id: "\(fortune.date)-\(offset)", title: item.0, symbolName: item.1)
        }
        charm = Self.charms.element(for: seed.derived("charm"))
    }

    private static let taskPool: [(String, String)] = [
        ("お気に入りの曲を一曲だけ聴く", "music.note"),
        ("鏡の中の自分に『今日もいい感じ』", "sparkles"),
        ("温かい飲み物をゆっくり味わう", "mug"),
        ("空を見上げて深呼吸を三回", "cloud.sun"),
        ("好きな人にやさしい一言を送る", "paperplane"),
        ("バッグの中をひとつだけ整える", "handbag"),
        ("今日かわいいと思ったものを撮る", "camera"),
        ("いつもと違う香りを選ぶ", "drop"),
        ("寝る前に肩をゆっくり回す", "figure.cooldown"),
        ("明日着たい服をひとつ決める", "tshirt"),
        ("小さなおやつを丁寧に楽しむ", "birthday.cake"),
        ("誰かの素敵なところを見つける", "heart"),
        ("机の上を一分だけ片づける", "lamp.desk"),
        ("今の気持ちを三文字で書く", "pencil.line"),
        ("通知を閉じて五分だけ自分時間", "moon.zzz")
    ]

    private static let charms = [
        DailyCharm(emoji: "🌙", name: "月のしずく", message: "静かな魅力が育つ日。"),
        DailyCharm(emoji: "🎀", name: "結びリボン", message: "うれしい縁をそっと結んで。"),
        DailyCharm(emoji: "🫧", name: "夢色バブル", message: "軽やかな気分を忘れずに。"),
        DailyCharm(emoji: "🦋", name: "きらめき蝶", message: "小さな変化が味方になります。"),
        DailyCharm(emoji: "🌸", name: "花びら便り", message: "やさしい言葉が届く日。"),
        DailyCharm(emoji: "🪞", name: "星のミラー", message: "あなたらしさがいちばんの魔法。"),
        DailyCharm(emoji: "💎", name: "ひみつの宝石", message: "今日のときめきを大切に。"),
        DailyCharm(emoji: "🪽", name: "天使の羽", message: "無理せず軽やかなほうへ。"),
        DailyCharm(emoji: "🍓", name: "恋するベリー", message: "素直な笑顔がチャームポイント。"),
        DailyCharm(emoji: "⭐️", name: "一番星", message: "最初の一歩を星が見守ります。")
    ]
}
