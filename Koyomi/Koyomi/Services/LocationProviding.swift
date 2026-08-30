import Foundation
import KoyomiCore
#if canImport(CoreLocation)
import CoreLocation
#endif

/// 位置情報の権限状態。UI はこの値だけを見る。
enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
}

/// 都市レベルの場所。緯度経度は天気取得のためだけに保持し、保存はしない。
struct ResolvedPlace: Equatable, Sendable {
    let cityName: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String

    init(city: City) {
        self.cityName = city.japaneseName
        self.latitude = city.latitude
        self.longitude = city.longitude
        self.timeZoneIdentifier = city.timeZoneIdentifier
    }

    init(cityName: String, latitude: Double, longitude: Double, timeZoneIdentifier: String) {
        self.cityName = cityName
        self.latitude = latitude
        self.longitude = longitude
        self.timeZoneIdentifier = timeZoneIdentifier
    }

    var calendar: Calendar { KoyomiCalendar.calendar(timeZoneIdentifier: timeZoneIdentifier) }
}

@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    /// システムの権限ダイアログを出す。ユーザーが説明を読んだ後にだけ呼ぶ。
    func requestWhenInUseAuthorization() async -> LocationAuthorization
    /// 現在地を都市レベルに解決する。許可されていない場合は nil。
    func currentPlace() async -> ResolvedPlace?
    /// 設定アプリから戻ったときなどに権限状態を読み直す。
    func refreshAuthorization()
}

#if canImport(CoreLocation)
/// Core Location 実装。`When In Use` のみを要求し、バックグラウンド測位は使わない。
@MainActor
final class CoreLocationProvider: NSObject, LocationProviding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var authorizationContinuation: CheckedContinuation<LocationAuthorization, Never>?
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    private(set) var authorization: LocationAuthorization = .notDetermined

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyReduced
        authorization = Self.map(manager.authorizationStatus)
    }

    func refreshAuthorization() {
        authorization = Self.map(manager.authorizationStatus)
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorization {
        refreshAuthorization()
        guard authorization == .notDetermined else { return authorization }
        return await withCheckedContinuation { continuation in
            authorizationContinuation = continuation
            manager.requestWhenInUseAuthorization()
        }
    }

    func currentPlace() async -> ResolvedPlace? {
        refreshAuthorization()
        guard authorization == .authorized else { return nil }
        guard let location = await requestLocation() else { return nil }
        return await reverseGeocode(location)
    }

    private func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    /// 逆ジオコーディングは表示に必要な都市名だけを取り出す。
    private func reverseGeocode(_ location: CLLocation) async -> ResolvedPlace? {
        let geocoder = CLGeocoder()
        let cityName: String
        var timeZoneIdentifier = TimeZone.current.identifier
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "ja_JP"))
            let placemark = placemarks.first
            cityName = placemark?.locality ?? placemark?.administrativeArea ?? "現在の場所"
            if let identifier = placemark?.timeZone?.identifier { timeZoneIdentifier = identifier }
        } catch {
            cityName = "現在の場所"
        }
        return ResolvedPlace(
            cityName: cityName,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timeZoneIdentifier: timeZoneIdentifier
        )
    }

    static func map(_ status: CLAuthorizationStatus) -> LocationAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted, .denied: .denied
        case .authorizedAlways, .authorizedWhenInUse: .authorized
        @unknown default: .denied
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let mapped = Self.map(manager.authorizationStatus)
        authorization = mapped
        if mapped != .notDetermined, let continuation = authorizationContinuation {
            authorizationContinuation = nil
            continuation.resume(returning: mapped)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: locations.last)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let continuation = locationContinuation else { return }
        locationContinuation = nil
        continuation.resume(returning: nil)
    }
}
#endif

/// テスト・プレビュー用。権限ダイアログを出さない。
@MainActor
final class StubLocationProvider: LocationProviding {
    private(set) var authorization: LocationAuthorization
    private let place: ResolvedPlace?

    init(authorization: LocationAuthorization = .authorized, place: ResolvedPlace? = ResolvedPlace(city: .tokyo)) {
        self.authorization = authorization
        self.place = place
    }

    func requestWhenInUseAuthorization() async -> LocationAuthorization {
        authorization
    }

    func currentPlace() async -> ResolvedPlace? {
        authorization == .authorized ? place : nil
    }

    func refreshAuthorization() {}
}
