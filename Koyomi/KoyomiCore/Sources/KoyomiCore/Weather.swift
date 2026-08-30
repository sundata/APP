import Foundation

/// 占い生成に使う天気の有限枚数。WeatherKit の詳細な condition はここへ写像する。
public enum WeatherCategory: String, Codable, CaseIterable, Sendable {
    case clear
    case cloudy
    case rain
    case snow
    case thunderstorm
    case fog
    case wind
    case extremeHeat
    case extremeCold

    public var japaneseName: String {
        switch self {
        case .clear: "晴れ"
        case .cloudy: "くもり"
        case .rain: "雨"
        case .snow: "雪"
        case .thunderstorm: "雷雨"
        case .fog: "霧"
        case .wind: "強風"
        case .extremeHeat: "猛暑"
        case .extremeCold: "厳しい寒さ"
        }
    }

    /// SF Symbols 名（アイコンのみで情報を伝えないよう、必ずテキストと併記する）。
    public var symbolName: String {
        switch self {
        case .clear: "sun.max"
        case .cloudy: "cloud"
        case .rain: "cloud.rain"
        case .snow: "snowflake"
        case .thunderstorm: "cloud.bolt.rain"
        case .fog: "cloud.fog"
        case .wind: "wind"
        case .extremeHeat: "thermometer.sun"
        case .extremeCold: "thermometer.snowflake"
        }
    }

    /// シードに使う安定した序数。
    public var ordinal: Int {
        switch self {
        case .clear: 0
        case .cloudy: 1
        case .rain: 2
        case .snow: 3
        case .thunderstorm: 4
        case .fog: 5
        case .wind: 6
        case .extremeHeat: 7
        case .extremeCold: 8
        }
    }

    /// 猛暑・厳寒・雷雨など、客観的な注意喚起を優先すべき天気か。
    public var deservesCaution: Bool {
        switch self {
        case .thunderstorm, .extremeHeat, .extremeCold, .snow, .wind: true
        case .clear, .cloudy, .rain, .fog: false
        }
    }
}

/// 都市（定位を拒否した場合の手動選択肢）。緯度経度は天気取得のみに使う。
public struct City: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let japaneseName: String
    public let latitude: Double
    public let longitude: Double
    public let timeZoneIdentifier: String

    public init(id: String, japaneseName: String, latitude: Double, longitude: Double, timeZoneIdentifier: String = "Asia/Tokyo") {
        self.id = id
        self.japaneseName = japaneseName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    public var calendar: Calendar { KoyomiCalendar.calendar(timeZoneIdentifier: timeZoneIdentifier) }

    public static let sapporo = City(id: "sapporo", japaneseName: "札幌", latitude: 43.0618, longitude: 141.3545)
    public static let sendai = City(id: "sendai", japaneseName: "仙台", latitude: 38.2682, longitude: 140.8694)
    public static let tokyo = City(id: "tokyo", japaneseName: "東京", latitude: 35.6812, longitude: 139.7671)
    public static let nagoya = City(id: "nagoya", japaneseName: "名古屋", latitude: 35.1709, longitude: 136.8815)
    public static let osaka = City(id: "osaka", japaneseName: "大阪", latitude: 34.7025, longitude: 135.4959)
    public static let hiroshima = City(id: "hiroshima", japaneseName: "広島", latitude: 34.3853, longitude: 132.4553)
    public static let fukuoka = City(id: "fukuoka", japaneseName: "福岡", latitude: 33.5902, longitude: 130.4207)
    public static let naha = City(id: "naha", japaneseName: "那覇", latitude: 26.2124, longitude: 127.6809)

    /// 定位を使わないユーザー向けの選択肢。
    public static let selectable: [City] = [
        .sapporo, .sendai, .tokyo, .nagoya, .osaka, .hiroshima, .fukuoka, .naha
    ]

    public static func city(id: String) -> City? {
        selectable.first { $0.id == id }
    }
}

/// 永続化する天気スナップショット。緯度経度は含めない（都市名と要約のみ）。
public struct WeatherSnapshot: Codable, Hashable, Sendable {
    public let category: WeatherCategory
    public let temperature: Double
    public let highTemperature: Double
    public let lowTemperature: Double
    public let precipitationChance: Double
    public let humidity: Double
    public let windSpeed: Double
    public let cityName: String
    public let capturedAt: Date

    public init(
        category: WeatherCategory,
        temperature: Double,
        highTemperature: Double,
        lowTemperature: Double,
        precipitationChance: Double,
        humidity: Double,
        windSpeed: Double,
        cityName: String,
        capturedAt: Date
    ) {
        self.category = category
        self.temperature = temperature
        self.highTemperature = highTemperature
        self.lowTemperature = lowTemperature
        self.precipitationChance = precipitationChance
        self.humidity = humidity
        self.windSpeed = windSpeed
        self.cityName = cityName
        self.capturedAt = capturedAt
    }

    /// 表示用の気温（例: 27°）。
    public var temperatureText: String { "\(Int(temperature.rounded()))°" }
    public var highLowText: String { "最高\(Int(highTemperature.rounded()))° / 最低\(Int(lowTemperature.rounded()))°" }
    public var precipitationText: String { "降水確率 \(Int((precipitationChance * 100).rounded()))%" }

    /// 取得から一定時間が経過していれば「更新時刻付きの古い情報」として扱う。
    public func isStale(now: Date, allowance: TimeInterval = 60 * 60) -> Bool {
        now.timeIntervalSince(capturedAt) > allowance
    }
}

/// 天気の取得結果。fallback と「キャッシュ表示」を UI で区別できるようにする。
public enum WeatherAvailability: Codable, Hashable, Sendable {
    case fresh(WeatherSnapshot)
    case cached(WeatherSnapshot)
    case unavailable

    public var snapshot: WeatherSnapshot? {
        switch self {
        case .fresh(let snapshot), .cached(let snapshot): snapshot
        case .unavailable: nil
        }
    }
}
