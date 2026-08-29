import Foundation

/// 各運勢カテゴリのスコアと一言。
public struct CategoryFortune: Codable, Hashable, Sendable {
    public let score: Int
    public let text: String

    public init(score: Int, text: String) {
        self.score = score
        self.text = text
    }
}

/// ラッキーカラー。色だけで情報を伝えないよう、必ず名前と併記する。
public struct LuckyColor: Codable, Hashable, Sendable {
    public let name: String
    public let hex: String

    public init(name: String, hex: String) {
        self.name = name
        self.hex = hex
    }
}

/// 1 日分の占い結果。要件定義書 5.3 の JSON 構造と一致する。
public struct DailyFortune: Codable, Hashable, Identifiable, Sendable {
    public let date: String
    public let zodiac: Zodiac
    public let overallScore: Int
    public let headline: String
    public let overall: String
    public let skySign: String
    public let love: CategoryFortune
    public let workStudy: CategoryFortune
    public let beautyHealth: CategoryFortune
    public let social: CategoryFortune
    public let luckyColor: LuckyColor
    public let luckyItem: String
    public let luckyTime: String
    public let action: String
    public let disclaimer: String
    /// 生成に使ったコンテンツのバージョン。内容更新時の再生成判定に使う。
    public let contentVersion: Int
    /// 天気を使わずに生成した結果か（UI で「お天気情報を取得できませんでした」を出す判断に使う）。
    public let usedWeather: Bool

    public var id: String { "\(date)-\(zodiac.rawValue)" }

    public init(
        date: String,
        zodiac: Zodiac,
        overallScore: Int,
        headline: String,
        overall: String,
        skySign: String,
        love: CategoryFortune,
        workStudy: CategoryFortune,
        beautyHealth: CategoryFortune,
        social: CategoryFortune,
        luckyColor: LuckyColor,
        luckyItem: String,
        luckyTime: String,
        action: String,
        disclaimer: String = DailyFortune.standardDisclaimer,
        contentVersion: Int,
        usedWeather: Bool
    ) {
        self.date = date
        self.zodiac = zodiac
        self.overallScore = overallScore
        self.headline = headline
        self.overall = overall
        self.skySign = skySign
        self.love = love
        self.workStudy = workStudy
        self.beautyHealth = beautyHealth
        self.social = social
        self.luckyColor = luckyColor
        self.luckyItem = luckyItem
        self.luckyTime = luckyTime
        self.action = action
        self.disclaimer = disclaimer
        self.contentVersion = contentVersion
        self.usedWeather = usedWeather
    }

    public static let standardDisclaimer = "占いは毎日を楽しむためのヒントです。"

    /// VoiceOver 用のスコア読み上げ（例: 5段階中4）。
    public static func accessibilityScoreText(_ score: Int) -> String {
        "5段階中\(score)"
    }
}

/// 占い生成の入力。View から直接組み立てず、ViewModel 経由で渡す。
public struct FortuneInput: Hashable, Sendable {
    public let zodiac: Zodiac
    /// 表示都市のローカル日付キー（yyyy-MM-dd）。
    public let dayKey: String
    /// 1970-01-01 からの経過日数。7 日間の重複回避に使う。
    public let dayNumber: Int
    public let season: Season
    public let weather: WeatherSnapshot?
    public let moonPhase: MoonPhase?

    public init(
        zodiac: Zodiac,
        dayKey: String,
        dayNumber: Int,
        season: Season,
        weather: WeatherSnapshot?,
        moonPhase: MoonPhase? = nil
    ) {
        self.zodiac = zodiac
        self.dayKey = dayKey
        self.dayNumber = dayNumber
        self.season = season
        self.weather = weather
        self.moonPhase = moonPhase
    }

    /// 日付・都市のカレンダーから入力を組み立てる。
    public init(
        zodiac: Zodiac,
        date: Date,
        calendar: Calendar,
        weather: WeatherSnapshot?,
        moonPhase: MoonPhase? = nil
    ) {
        self.init(
            zodiac: zodiac,
            dayKey: KoyomiCalendar.dayKey(for: date, calendar: calendar),
            dayNumber: KoyomiCalendar.dayNumber(for: date, calendar: calendar),
            season: Season.from(date: date, calendar: calendar),
            weather: weather,
            moonPhase: moonPhase
        )
    }
}

/// 占い生成の抽象。テストでは差し替え可能。
public protocol FortuneGenerating: Sendable {
    func fortune(for input: FortuneInput) -> DailyFortune
}
