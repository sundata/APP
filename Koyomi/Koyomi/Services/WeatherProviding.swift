import Foundation
import KoyomiCore
#if canImport(WeatherKit)
import WeatherKit
#endif
#if canImport(CoreLocation)
import CoreLocation
#endif

/// 天気取得の抽象。View からは触らず、ViewModel 経由で使う。
protocol WeatherProviding: Sendable {
    /// 都市（または現在地）の天気スナップショットを返す。
    func snapshot(latitude: Double, longitude: Double, cityName: String) async throws -> WeatherSnapshot
    /// 信頼できる月相が取得できた場合のみ返す。取得できなければ nil。
    func moonPhase(latitude: Double, longitude: Double) async -> KoyomiCore.MoonPhase?
}

enum WeatherProviderError: Error {
    case timedOut
    case unavailable
}

/// 一定時間で必ず打ち切る（無限ローディングを避ける）。
func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @escaping @Sendable () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw WeatherProviderError.timedOut
        }
        guard let result = try await group.next() else { throw WeatherProviderError.timedOut }
        group.cancelAll()
        return result
    }
}

#if canImport(WeatherKit) && canImport(CoreLocation)
/// Apple WeatherKit 実装。
/// 位置情報（緯度経度）は天気の取得のみに使い、保存もログ出力もしない。
struct WeatherKitWeatherProvider: WeatherProviding {
    let timeout: Double

    init(timeout: Double = 4.0) {
        self.timeout = timeout
    }

    func snapshot(latitude: Double, longitude: Double, cityName: String) async throws -> WeatherSnapshot {
        try await withTimeout(seconds: timeout) {
            let location = CLLocation(latitude: latitude, longitude: longitude)
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let today = weather.dailyForecast.forecast.first

            return WeatherSnapshot(
                category: Self.category(
                    for: current.condition,
                    temperature: current.temperature.converted(to: .celsius).value,
                    windSpeed: current.wind.speed.converted(to: .metersPerSecond).value
                ),
                temperature: current.temperature.converted(to: .celsius).value,
                highTemperature: today?.highTemperature.converted(to: .celsius).value
                    ?? current.temperature.converted(to: .celsius).value,
                lowTemperature: today?.lowTemperature.converted(to: .celsius).value
                    ?? current.temperature.converted(to: .celsius).value,
                precipitationChance: today?.precipitationChance ?? 0,
                humidity: current.humidity,
                windSpeed: current.wind.speed.converted(to: .metersPerSecond).value,
                cityName: cityName,
                capturedAt: Date()
            )
        }
    }

    func moonPhase(latitude: Double, longitude: Double) async -> KoyomiCore.MoonPhase? {
        do {
            return try await withTimeout(seconds: timeout) {
                let location = CLLocation(latitude: latitude, longitude: longitude)
                let weather = try await WeatherService.shared.weather(for: location)
                guard let moon = weather.dailyForecast.forecast.first?.moon else { return nil }
                return Self.moonPhase(for: moon.phase)
            }
        } catch {
            // 取得できないときは推測せず nil を返す。
            return nil
        }
    }

    /// WeatherKit の詳細な condition を、占いで使う有限枚数へ写像する。
    static func category(for condition: WeatherCondition, temperature: Double, windSpeed: Double) -> WeatherCategory {
        if temperature >= 35 { return .extremeHeat }
        if temperature <= -5 { return .extremeCold }

        switch condition {
        case .clear, .mostlyClear, .hot:
            return temperature >= 35 ? .extremeHeat : .clear
        case .partlyCloudy, .mostlyCloudy, .cloudy:
            return .cloudy
        case .drizzle, .rain, .heavyRain, .sunShowers, .freezingDrizzle, .freezingRain, .hail:
            return .rain
        case .flurries, .snow, .heavySnow, .sleet, .blizzard, .blowingSnow, .wintryMix, .frigid:
            return condition == .frigid ? .extremeCold : .snow
        case .thunderstorms, .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return .thunderstorm
        case .foggy, .haze, .smoky:
            return .fog
        case .breezy, .windy, .blowingDust:
            return .wind
        @unknown default:
            return windSpeed >= 10 ? .wind : .cloudy
        }
    }

    static func moonPhase(for phase: WeatherKit.MoonPhase) -> KoyomiCore.MoonPhase? {
        switch phase {
        case .new: .newMoon
        case .waxingCrescent: .waxingCrescent
        case .firstQuarter: .firstQuarter
        case .waxingGibbous: .waxingGibbous
        case .full: .fullMoon
        case .waningGibbous: .waningGibbous
        case .lastQuarter: .lastQuarter
        case .waningCrescent: .waningCrescent
        @unknown default: nil
        }
    }
}
#endif

/// 開発・テスト用のモック。ネットワークを使わない。
struct MockWeatherProvider: WeatherProviding {
    let category: WeatherCategory
    let temperature: Double
    let failure: Error?
    let fixedMoonPhase: KoyomiCore.MoonPhase?

    init(
        category: WeatherCategory = .cloudy,
        temperature: Double = 26,
        failure: Error? = nil,
        fixedMoonPhase: KoyomiCore.MoonPhase? = nil
    ) {
        self.category = category
        self.temperature = temperature
        self.failure = failure
        self.fixedMoonPhase = fixedMoonPhase
    }

    func snapshot(latitude: Double, longitude: Double, cityName: String) async throws -> WeatherSnapshot {
        if let failure { throw failure }
        return WeatherSnapshot(
            category: category,
            temperature: temperature,
            highTemperature: temperature + 3,
            lowTemperature: temperature - 4,
            precipitationChance: category == .rain ? 0.7 : 0.1,
            humidity: 0.6,
            windSpeed: 2.0,
            cityName: cityName,
            capturedAt: Date()
        )
    }

    func moonPhase(latitude: Double, longitude: Double) async -> KoyomiCore.MoonPhase? {
        fixedMoonPhase
    }
}
