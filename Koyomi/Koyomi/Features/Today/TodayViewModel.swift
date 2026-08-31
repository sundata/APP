import Foundation
import Observation
import KoyomiCore

/// 今日ページの状態。View は WeatherKit / 位置情報 / 永続化を直接触らない。
@MainActor
@Observable
final class TodayViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private let environment: AppEnvironment

    var state: LoadState = .idle
    var fortune: DailyFortune?
    var weather: WeatherAvailability = .unavailable
    /// 天気が使えない理由の日本語表示。天気を偽装しないため必ず明示する。
    var weatherNotice: String?
    var cityName: String = City.tokyo.japaneseName
    var isFavorite = false
    /// 位置情報が拒否されたときに都市選択を促す。
    var needsCityChoice = false
    var dayKey: String = ""
    var selectedMood: DailyMood?
    var reflectionDraft = ""
    var reflectionSaved = false
    var completedRitualTaskIDs: Set<String> = []
    var charmUnlocked = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var displayDate: String {
        KoyomiCalendar.displayDate(for: environment.clock.now, calendar: activeCalendar)
    }

    private var activeCalendar: Calendar {
        let preferences = environment.store.preferences()
        if let city = preferences.selectedCity {
            return KoyomiCalendar.calendar(timeZoneIdentifier: city.timeZoneIdentifier)
        }
        return KoyomiCalendar.calendar(timeZoneIdentifier: TimeZone.current.identifier)
    }

    /// 起動時・前面復帰時に呼ぶ。ローカル日付が変わっていれば今日の内容を作り直す。
    func load() async {
        let preferences = environment.store.preferences()
        guard preferences.onboardingCompleted else { return }
        if state == .loading { return }
        state = .loading

        environment.locationProvider.refreshAuthorization()
        let place = await resolvePlace(preferences: preferences)
        cityName = place?.cityName ?? preferences.selectedCity?.japaneseName ?? City.tokyo.japaneseName
        needsCityChoice = place == nil

        let calendar = place.map(\.calendar) ?? activeCalendar
        let now = environment.clock.now
        let key = KoyomiCalendar.dayKey(for: now, calendar: calendar)
        dayKey = key
        selectedMood = environment.store.mood(dayKey: key)
        reflectionDraft = environment.store.reflection(dayKey: key)
        reflectionSaved = !reflectionDraft.isEmpty
        let ritualRecord = environment.store.ritualRecord(dayKey: key)
        completedRitualTaskIDs = ritualRecord?.completedTaskIDs ?? []
        charmUnlocked = ritualRecord?.hasCharm ?? false

        let availability = await loadWeather(place: place, now: now, dayKey: key)
        weather = availability
        weatherNotice = notice(for: availability, now: now)

        // 当日分がすでに保存されていれば、その内容をそのまま使う（更新で変わらない）。
        if let saved = environment.store.record(dayKey: key), let savedFortune = saved.fortune {
            fortune = savedFortune
            isFavorite = saved.isFavorite
            environment.store.persist(fortune: savedFortune, weather: availability.snapshot, cityName: cityName)
            state = .loaded
            return
        }

        let moonPhase: KoyomiCore.MoonPhase?
        if let place {
            moonPhase = await environment.weatherProvider.moonPhase(latitude: place.latitude, longitude: place.longitude)
        } else {
            moonPhase = nil
        }

        let input = FortuneInput(
            zodiac: preferences.zodiac,
            date: now,
            calendar: calendar,
            weather: availability.snapshot,
            moonPhase: moonPhase
        )
        let generated = environment.fortuneGenerator.fortune(for: input)
        fortune = generated
        let record = environment.store.persist(fortune: generated, weather: availability.snapshot, cityName: cityName)
        isFavorite = record.isFavorite
        state = .loaded
    }

    /// 引っぱって更新：天気だけを取り直す。核となる占いは同じ日なら変えない。
    func refreshWeather() async {
        await load()
    }

    func toggleFavorite() {
        guard !dayKey.isEmpty else { return }
        environment.store.toggleFavorite(dayKey: dayKey)
        isFavorite = environment.store.record(dayKey: dayKey)?.isFavorite ?? false
    }

    func selectMood(_ mood: DailyMood) {
        guard !dayKey.isEmpty else { return }
        selectedMood = mood
        environment.store.saveMood(mood, dayKey: dayKey)
    }

    func saveReflection() {
        guard !dayKey.isEmpty else { return }
        environment.store.saveReflection(reflectionDraft, dayKey: dayKey)
        reflectionDraft = environment.store.reflection(dayKey: dayKey)
        reflectionSaved = !reflectionDraft.isEmpty
    }

    var lifestyleContent: DailyLifestyleContent? {
        fortune.map(DailyLifestyleContent.init(fortune:))
    }

    var ritualContent: DailyRitualContent? {
        fortune.map(DailyRitualContent.init(fortune:))
    }

    func toggleRitualTask(_ task: DailyRitualTask) {
        guard !dayKey.isEmpty, let ritualContent else { return }
        let record = environment.store.toggleRitualTask(id: task.id, dayKey: dayKey, charm: ritualContent.charm)
        completedRitualTaskIDs = record.completedTaskIDs
        charmUnlocked = record.hasCharm
    }

    func selectCity(_ city: City) async {
        let preferences = environment.store.preferences()
        preferences.selectedCityID = city.id
        preferences.usesCurrentLocation = false
        environment.store.save()
        state = .idle
        await load()
    }

    var shareCardContent: ShareCardContent? {
        guard let fortune else { return nil }
        return ShareCardContent(fortune: fortune, dateText: displayDate)
    }

    // MARK: - 内部

    private func resolvePlace(preferences: UserPreferencesRecord) async -> ResolvedPlace? {
        if preferences.usesCurrentLocation,
           environment.locationProvider.authorization == .authorized,
           let place = await environment.locationProvider.currentPlace() {
            return place
        }
        if let city = preferences.selectedCity {
            return ResolvedPlace(city: city)
        }
        return nil
    }

    private func loadWeather(place: ResolvedPlace?, now: Date, dayKey: String) async -> WeatherAvailability {
        guard let place else { return cachedWeather(dayKey: dayKey) }
        do {
            let snapshot = try await environment.weatherProvider.snapshot(
                latitude: place.latitude,
                longitude: place.longitude,
                cityName: place.cityName
            )
            return .fresh(snapshot)
        } catch {
            return cachedWeather(dayKey: dayKey)
        }
    }

    /// 当日の保存済み天気があれば「更新時刻付き」で見せる。なければ天気なしで進む。
    private func cachedWeather(dayKey: String) -> WeatherAvailability {
        if let cached = environment.store.record(dayKey: dayKey)?.weather {
            return .cached(cached)
        }
        return .unavailable
    }

    private func notice(for availability: WeatherAvailability, now: Date) -> String? {
        switch availability {
        case .fresh:
            return nil
        case .cached(let snapshot):
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ja_JP")
            formatter.dateFormat = "HH:mm"
            return "お天気は\(formatter.string(from: snapshot.capturedAt))時点の情報です。"
        case .unavailable:
            return "お天気情報を取得できませんでした。季節と日付から今日のヒントをお届けします。"
        }
    }
}
