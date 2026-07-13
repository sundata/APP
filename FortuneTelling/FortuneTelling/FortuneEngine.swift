import Foundation

enum FortuneEngine {
    private static let colors = ["桜ピンク", "藤むらさき", "月白", "瑠璃紺", "淡い金色", "若草色"]
    private static let items = ["小さな手帳", "白いハンカチ", "月のモチーフ", "温かいお茶", "お気に入りの香り", "丸いアクセサリー"]
    private static let advices = [
        "今日は急いで答えを出すより、気持ちが落ち着く選択を大切にしてみてください。",
        "小さな予定を一つ整えると、午後から流れが軽くなりそうです。",
        "相手の反応を読みすぎず、自分の心地よさも同じくらい尊重すると良い日です。",
        "迷いがある時は、できることを一つだけ選ぶと運気が動き出します。",
        "言葉をやわらかくすると、人間関係にうれしい余白が生まれそうです。"
    ]

    static func todayFortune(for profile: UserProfile, date: Date = .now) -> FortuneResult {
        let seed = stableSeed(from: profile.nickname + dayKey(for: date))
        return FortuneResult(
            date: date,
            overall: score(seed, offset: 1),
            love: score(seed, offset: 2),
            work: score(seed, offset: 3),
            money: score(seed, offset: 4),
            health: score(seed, offset: 5),
            luckyColor: colors[seed % colors.count],
            luckyItem: items[(seed / 3) % items.count],
            advice: advices[(seed / 7) % advices.count],
            detail: detailedAdvice(seed: seed, profile: profile)
        )
    }

    static func zodiacName(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.month, .day], from: date)
        let month = components.month ?? 1
        let day = components.day ?? 1
        return switch (month, day) {
        case (3, 21...31), (4, 1...19): "牡羊座"
        case (4, 20...30), (5, 1...20): "牡牛座"
        case (5, 21...31), (6, 1...21): "双子座"
        case (6, 22...30), (7, 1...22): "蟹座"
        case (7, 23...31), (8, 1...22): "獅子座"
        case (8, 23...31), (9, 1...22): "乙女座"
        case (9, 23...30), (10, 1...23): "天秤座"
        case (10, 24...31), (11, 1...22): "蠍座"
        case (11, 23...30), (12, 1...21): "射手座"
        case (12, 22...31), (1, 1...19): "山羊座"
        case (1, 20...31), (2, 1...18): "水瓶座"
        default: "魚座"
        }
    }

    static func lifePathNumber(for date: Date) -> Int {
        let digits = DateFormatter.numericBirthday.string(from: date).compactMap(\.wholeNumberValue)
        var total = digits.reduce(0, +)
        while total > 9 {
            total = String(total).compactMap(\.wholeNumberValue).reduce(0, +)
        }
        return max(total, 1)
    }

    static func birthFortunes(for profile: UserProfile) -> [BirthFortune] {
        let zodiac = zodiacName(for: profile.birthday)
        let number = lifePathNumber(for: profile.birthday)
        let seed = stableSeed(from: profile.nickname + DateFormatter.numericBirthday.string(from: profile.birthday))
        return [
            BirthFortune(
                id: "zodiac",
                title: "星座占い",
                summary: "\(zodiac)は、人との距離感を丁寧に整えるほど魅力が伝わりやすいタイプです。",
                advice: "今日の開運行動は、先に小さな感謝を伝えることです。"
            ),
            BirthFortune(
                id: "birthday",
                title: "誕生日占い",
                summary: "誕生日の流れでは、直感よりも継続の力で運を育てる傾向があります。",
                advice: ["朝に予定を整える", "好きな香りを使う", "古いメモを見直す"][seed % 3]
            ),
            BirthFortune(
                id: "numerology",
                title: "数秘術",
                summary: "ライフパス\(number)は、自分のペースを守るほど周囲にも良い影響を渡せます。",
                advice: "迷ったら、気持ちが軽くなる選択を一つだけ選んでください。"
            ),
            BirthFortune(
                id: "fourPillars",
                title: "四柱推命風",
                summary: "今期は「整える力」が運気の軸。生活リズムや人間関係の微調整に向いています。",
                advice: "急な勝負より、準備を重ねる方が結果につながりやすい日です。"
            ),
            BirthFortune(
                id: "blood",
                title: "血液型占い",
                summary: "\(profile.bloodType)型の流れでは、言葉の選び方が印象を左右しやすい時期です。",
                advice: "返信や相談は短くやさしくまとめると、関係が進みやすくなります。"
            )
        ]
    }

    static func compatibility(userBirthday: Date, partnerBirthday: Date, relationship: Relationship, concern: String) -> CompatibilityResult {
        let key = DateFormatter.numericBirthday.string(from: userBirthday)
            + DateFormatter.numericBirthday.string(from: partnerBirthday)
            + relationship.rawValue
            + concern
        let seed = stableSeed(from: key)
        let score = 58 + seed % 38
        return CompatibilityResult(
            score: score,
            feeling: "相手はあなたの空気感に安心しやすい時期です。ただ、返事や態度だけで気持ちを決めつけない方が良さそうです。",
            flow: "近いうちに小さな会話のきっかけが生まれやすい流れです。重い話題より、日常の共有から始めると自然に進みます。",
            contactDay: ["月曜日", "水曜日", "金曜日", "日曜日"][seed % 4],
            avoidAction: "不安な気持ちのまま連続で確認すること。相手に考える余白を渡すと関係が整いやすくなります。",
            advice: "今は一気に答えを求めるより、短く明るい言葉で接点を作るのがおすすめです。"
        )
    }

    static func answer(for question: String, remainingCount: Int, turn: Int = 0) -> String {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        let seed = stableSeed(from: trimmed + dayKey(for: .now) + "\(turn)")
        let remainingText = remainingCount == Int.max ? "Premium: 無制限" : "残り相談回数: \(remainingCount)回"
        let empathy = [
            "不安になりますよね。",
            "その状況だと、気持ちが揺れてしまいますよね。",
            "答えが見えない時ほど、心が忙しくなりますよね。",
            "ちゃんと大切にしたいからこそ、迷ってしまうのだと思います。"
        ][seed % 4]
        let moonTone = [
            "今夜の月の流れでは",
            "星の配置に重ねて見ると",
            "いま届いている雰囲気では",
            "今日の運気としては"
        ][(seed / 3) % 4]
        let action = [
            "長文で確認するより、軽い一言で空気をやわらげる",
            "今日すぐ結論を出さず、明日の自分が読んでも苦しくない言葉を選ぶ",
            "相手を動かそうとする前に、自分の不安を一度メモに出す",
            "できるだけ短く、明るい話題から接点を作る"
        ][(seed / 7) % 4]
        let closing = [
            "焦らなくて大丈夫。今のあなたに必要なのは、答えを急ぐことではなく、自分の魅力を取り戻す時間です。",
            "無理に追いかけるより、あなた自身のリズムを整える方が、結果的に関係も整いやすくなります。",
            "占いとしては、今日は大きく動く日というより、心を落ち着けて次の一手を選ぶ日です。",
            "断定はできませんが、今は小さく優しい行動が流れを変えやすい時期です。"
        ][(seed / 11) % 4]

        let body: String
        if containsAny(trimmed, ["彼", "恋", "復縁", "返信", "LINE", "好き", "結婚"]) {
            let insight = containsAny(trimmed, ["返信", "LINE"])
                ? "彼の気持ちが冷めたというより、少し自分のペースに戻っている可能性があります。"
                : containsAny(trimmed, ["復縁"])
                ? "完全に道が閉じたというより、まだ言葉にしきれていない感情が残っている流れです。"
                : containsAny(trimmed, ["結婚"])
                ? "将来の話は急に形にするより、安心感を積み重ねることで現実味が増していきそうです。"
                : "相手の心は、あなたをまったく意識していないわけではなさそうです。ただ今は、距離感を慎重に見ている気配があります。"
            body = "\(moonTone)、\(insight)\n\n今日は\(action)のが良さそうです。"
        } else if containsAny(trimmed, ["転職", "仕事", "会社", "職場", "上司"]) {
            body = "\(moonTone)、仕事運は「整理」と「準備」に寄っています。勢いで決めるより、条件・人間関係・体力の3つを分けて見ると答えが見えやすくなります。\n\n今日は\(action)ことで、次の判断が軽くなりそうです。"
        } else if containsAny(trimmed, ["金", "お金", "収入", "副業", "貯金"]) {
            body = "\(moonTone)、金運は大きな勝負より見直しに向いています。小さな支出を整えるほど、安心感が戻りやすい日です。\n\n今日は買う前に一晩置く、または必要なものを3つに絞ると運気が安定します。"
        } else {
            body = "\(moonTone)、心の流れは少し敏感になっています。誰かの反応を読みすぎるより、自分が本当は何を望んでいるかを確認する時間が必要そうです。\n\n今日は\(action)のが開運につながります。"
        }

        return """
        \(empathy)

        \(body)

        \(closing)

        \(remainingText)
        """
    }

    static func omikuji(for profile: UserProfile, date: Date = .now) -> OmikujiResult {
        let seed = stableSeed(from: profile.nickname + dayKey(for: date) + "omikuji")
        let ranks = ["大吉", "中吉", "小吉", "吉", "末吉"]
        return OmikujiResult(
            rank: ranks[seed % ranks.count],
            message: [
                "思い込みを少しゆるめると、新しい流れが入ってきます。",
                "返事を急がず、相手のペースを見ることで運が整います。",
                "身の回りを一つ片づけると、気持ちも運気も軽くなります。",
                "今日は小さな挑戦に向く日。完璧より一歩を大切にしてください。"
            ][(seed / 5) % 4],
            charm: items[(seed / 11) % items.count]
        )
    }

    static func periodFortune(title: String, profile: UserProfile, days: Int) -> String {
        let seed = stableSeed(from: title + profile.nickname + "\(days)")
        let focus = ["恋愛", "仕事", "金運", "健康", "人間関係"][seed % 5]
        return "\(title)は\(focus)の流れが動きやすい時期です。焦って大きく変えるより、毎日続けられる小さな行動を決めると運が安定します。"
    }

    private static func score(_ seed: Int, offset: Int) -> Int {
        60 + abs(seed + offset * 17) % 40
    }

    private static func containsAny(_ text: String, _ words: [String]) -> Bool {
        words.contains { text.localizedCaseInsensitiveContains($0) }
    }

    private static func detailedAdvice(seed: Int, profile: UserProfile) -> String {
        let interest = profile.interests.sorted { $0.rawValue < $1.rawValue }.first?.rawValue ?? "毎日"
        let opening = [
            "午前中は情報を集め、午後に一つだけ決めると流れが整います。",
            "今日は人の言葉に揺れやすいので、自分の本音をメモしてから動くと安心です。",
            "小さな違和感をそのままにせず、予定や約束を丁寧に確認すると良い日です。"
        ][seed % 3]
        return "\(opening)\n\n特に\(interest)については、すぐに結果を求めるより、次につながる準備を整えることが開運になります。占いは参考として受け取り、重要な判断は信頼できる人や専門家にも相談してください。"
    }

    private static func stableSeed(from text: String) -> Int {
        text.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0x7fffffff }
    }

    private static func dayKey(for date: Date) -> String {
        DateFormatter.dayKey.string(from: date)
    }
}

private extension DateFormatter {
    static let dayKey: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    static let numericBirthday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}
