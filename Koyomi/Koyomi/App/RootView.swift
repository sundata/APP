import SwiftUI
import SwiftData
import KoyomiCore

/// onboarding と、記録を中心にした4タブの切り替え。
struct RootView: View {
    private enum AppTab: Hashable { case today, records, rhythm, profile }

    @Environment(\.scenePhase) private var scenePhase

    private let environment: AppEnvironment
    @State private var adMob = AdMobProvider.shared
    @State private var onboardingCompleted: Bool
    @State private var todayViewModel: TodayViewModel
    @State private var selectedTab: AppTab = .today

    init(container: ModelContainer) {
        let store = KoyomiStore(context: ModelContext(container))
        let arguments = ProcessInfo.processInfo.arguments
        let isUITesting = arguments.contains("-uiTesting") || arguments.contains("-uiTestingCurrentLocation")
        let isScreenshotTesting = arguments.contains("-screenshotTesting")
        let environment = (isUITesting || isScreenshotTesting)
            ? AppEnvironment.uiTesting(store: store)
            : AppEnvironment.live(store: store)
        if isScreenshotTesting {
            let preferences = store.preferences()
            preferences.nickname = "さくら"
            preferences.birthday = Date(timeIntervalSince1970: 946_684_800)
            preferences.zodiac = .capricorn
            preferences.selectedCityID = City.tokyo.id
            preferences.onboardingCompleted = true
            store.save()
            Self.seedScreenshotHistory(store: store, environment: environment, preferences: preferences)
        }
        self.environment = environment
        _onboardingCompleted = State(initialValue: store.preferences().onboardingCompleted)
        _todayViewModel = State(initialValue: TodayViewModel(environment: environment))
    }

    var body: some View {
        Group {
            if onboardingCompleted {
                VStack(spacing: 0) {
                    TabView(selection: $selectedTab) {
                        TodayView(viewModel: todayViewModel) {
                            adMob.presentInterstitialIfAvailable()
                        }
                            .tag(AppTab.today)
                            .tabItem { Label("今日", systemImage: "sun.and.horizon") }
                        CalendarView(environment: environment)
                            .tag(AppTab.records)
                            .tabItem { Label("記録", systemImage: "calendar") }
                        RhythmInsightsView(environment: environment)
                            .tag(AppTab.rhythm)
                            .tabItem { Label("リズム", systemImage: "chart.bar.xaxis") }
                        ProfileView(
                            environment: environment,
                            onReset: { onboardingCompleted = false }
                        )
                        .tag(AppTab.profile)
                        .tabItem { Label("わたし", systemImage: "person") }
                    }
                    .tint(KoyomiTheme.strawberryMilk)
                    .onChange(of: selectedTab) { _, tab in
                        guard tab == .today else { return }
                        Task { await todayViewModel.reload() }
                    }

                    if shouldShowAdBanner {
                        AdMobBannerView(adUnitID: AdMobProvider.bannerAdUnitID)
                            .background(.ultraThinMaterial)
                    }
                }
            } else {
                OnboardingView(environment: environment) {
                    onboardingCompleted = true
                    Task { await todayViewModel.load() }
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, onboardingCompleted else { return }
            // 設定から戻ったときの権限変化と、ローカル日付の切り替わりを反映する。
            Task { await todayViewModel.load() }
        }
        .task {
            let arguments = ProcessInfo.processInfo.arguments
            guard !arguments.contains("-uiTesting"),
                  !arguments.contains("-uiTestingCurrentLocation"),
                  !arguments.contains("-screenshotTesting") else { return }
            await adMob.prepare()
        }
    }

    private var shouldShowAdBanner: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return onboardingCompleted
            && adMob.canShowAds
            && !arguments.contains("-uiTesting")
            && !arguments.contains("-uiTestingCurrentLocation")
            && !arguments.contains("-screenshotTesting")
    }

    private static func seedScreenshotHistory(
        store: KoyomiStore,
        environment: AppEnvironment,
        preferences: UserPreferencesRecord
    ) {
        let calendar = KoyomiCalendar.calendar(timeZoneIdentifier: City.tokyo.timeZoneIdentifier)
        let moods: [DailyMood] = [.calm, .energized, .tired, .fluttering, .calm, .cloudy, .energized,
                                  .calm, .fluttering, .tired, .calm, .energized]
        let weatherCategories: [WeatherCategory] = [.clear, .cloudy, .rain, .clear, .cloudy, .rain,
                                                    .clear, .wind, .cloudy, .clear, .rain, .clear]

        for offset in 0..<moods.count {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: environment.clock.now) else { continue }
            let weather = WeatherSnapshot(
                category: weatherCategories[offset],
                temperature: 18 - Double(offset % 4),
                highTemperature: 22,
                lowTemperature: 13,
                precipitationChance: weatherCategories[offset] == .rain ? 0.7 : 0.1,
                humidity: 0.58,
                windSpeed: 2.4,
                cityName: City.tokyo.japaneseName,
                capturedAt: date
            )
            let fortune = environment.fortuneGenerator.fortune(for: FortuneInput(
                zodiac: preferences.zodiac,
                date: date,
                calendar: calendar,
                weather: weather
            ))
            store.persist(fortune: fortune, weather: weather, cityName: City.tokyo.japaneseName)
            store.saveMood(moods[offset], dayKey: fortune.date)
            if offset.isMultiple(of: 2) {
                store.saveReflection("今日うれしかった小さなことを、ひとつ見つけた。", dayKey: fortune.date)
            }
            let ritual = DailyRitualContent(fortune: fortune)
            if let task = ritual.tasks.first {
                _ = store.toggleRitualTask(id: task.id, dayKey: fortune.date, charm: ritual.charm)
            }
        }
    }
}
