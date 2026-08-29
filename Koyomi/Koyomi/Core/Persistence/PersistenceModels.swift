import Foundation
import SwiftData
import KoyomiCore

/// ユーザー設定（端末内のみ）。行はひとつだけ持つ。
@Model
final class UserPreferencesRecord {
    var nickname: String
    /// 生年月日。端末内のみに保存し、外部送信しない。
    var birthday: Date
    var zodiacRawValue: String
    /// 手動選択した都市の ID。現在地を使う場合は nil。
    var selectedCityID: String?
    var usesCurrentLocation: Bool
    var reminderEnabled: Bool
    var reminderHour: Int
    var reminderMinute: Int
    var onboardingCompleted: Bool

    init(
        nickname: String = "",
        birthday: Date = Date(timeIntervalSince1970: 0),
        zodiacRawValue: String = Zodiac.capricorn.rawValue,
        selectedCityID: String? = nil,
        usesCurrentLocation: Bool = false,
        reminderEnabled: Bool = false,
        reminderHour: Int = 7,
        reminderMinute: Int = 30,
        onboardingCompleted: Bool = false
    ) {
        self.nickname = nickname
        self.birthday = birthday
        self.zodiacRawValue = zodiacRawValue
        self.selectedCityID = selectedCityID
        self.usesCurrentLocation = usesCurrentLocation
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.onboardingCompleted = onboardingCompleted
    }

    var zodiac: Zodiac {
        get { Zodiac(rawValue: zodiacRawValue) ?? .capricorn }
        set { zodiacRawValue = newValue.rawValue }
    }

    var selectedCity: City? {
        guard let selectedCityID else { return nil }
        return City.city(id: selectedCityID)
    }

    var reminderComponents: DateComponents {
        DateComponents(hour: reminderHour, minute: reminderMinute)
    }
}

/// 1 日分の占い結果と、その日の天気要約。履歴は書き換えない。
@Model
final class FortuneRecord {
    /// ローカル日付キー（yyyy-MM-dd）。
    @Attribute(.unique) var dayKey: String
    var zodiacRawValue: String
    /// `DailyFortune` を JSON で保存する。生成ロジックを変えても履歴は変化しない。
    var fortuneData: Data
    /// 天気スナップショット（都市名と要約のみ。緯度経度は保存しない）。
    var weatherData: Data?
    var cityName: String
    var isFavorite: Bool
    var createdAt: Date

    init(
        dayKey: String,
        zodiacRawValue: String,
        fortuneData: Data,
        weatherData: Data?,
        cityName: String,
        isFavorite: Bool = false,
        createdAt: Date = Date()
    ) {
        self.dayKey = dayKey
        self.zodiacRawValue = zodiacRawValue
        self.fortuneData = fortuneData
        self.weatherData = weatherData
        self.cityName = cityName
        self.isFavorite = isFavorite
        self.createdAt = createdAt
    }

    var fortune: DailyFortune? {
        try? JSONDecoder().decode(DailyFortune.self, from: fortuneData)
    }

    var weather: WeatherSnapshot? {
        guard let weatherData else { return nil }
        return try? JSONDecoder().decode(WeatherSnapshot.self, from: weatherData)
    }
}
