import Foundation
import SwiftUI
import KoyomiCore

/// 依存性注入のコンテナ。View は具体実装を知らない。
@MainActor
final class AppEnvironment {
    let store: KoyomiStore
    let weatherProvider: WeatherProviding
    let fortuneGenerator: any FortuneGenerating
    let locationProvider: any LocationProviding
    let notificationScheduler: NotificationScheduling
    let clock: ClockProviding

    init(
        store: KoyomiStore,
        weatherProvider: WeatherProviding,
        fortuneGenerator: any FortuneGenerating = TemplateFortuneGenerator(),
        locationProvider: any LocationProviding,
        notificationScheduler: NotificationScheduling,
        clock: ClockProviding = SystemClock()
    ) {
        self.store = store
        self.weatherProvider = weatherProvider
        self.fortuneGenerator = fortuneGenerator
        self.locationProvider = locationProvider
        self.notificationScheduler = notificationScheduler
        self.clock = clock
    }

    /// 実機・シミュレータ用の既定構成。
    static func live(store: KoyomiStore) -> AppEnvironment {
        #if canImport(WeatherKit) && canImport(CoreLocation)
        let weather: WeatherProviding = WeatherKitWeatherProvider()
        #else
        let weather: WeatherProviding = MockWeatherProvider()
        #endif

        #if canImport(CoreLocation)
        let location: any LocationProviding = CoreLocationProvider()
        #else
        let location: any LocationProviding = StubLocationProvider(authorization: .notDetermined, place: nil)
        #endif

        #if canImport(UserNotifications)
        let notifications: NotificationScheduling = LocalNotificationScheduler()
        #else
        let notifications: NotificationScheduling = StubNotificationScheduler()
        #endif

        return AppEnvironment(
            store: store,
            weatherProvider: weather,
            locationProvider: location,
            notificationScheduler: notifications
        )
    }

    /// UI テスト用。ネットワークと権限ダイアログを使わず、時計も固定する。
    /// 起動引数 `-uiTesting` で有効になる。
    static func uiTesting(store: KoyomiStore) -> AppEnvironment {
        let fixed = Date(timeIntervalSince1970: 1_772_323_200) // 2026-03-01 09:00 JST
        return AppEnvironment(
            store: store,
            weatherProvider: MockWeatherProvider(category: .clear, temperature: 18),
            locationProvider: StubLocationProvider(authorization: .notDetermined, place: nil),
            notificationScheduler: StubNotificationScheduler(),
            clock: FixedClock(fixed)
        )
    }
}
