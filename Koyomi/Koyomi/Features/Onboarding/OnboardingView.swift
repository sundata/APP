import SwiftUI
import KoyomiCore

/// 4 画面の onboarding。アカウント登録は求めない。
/// 位置情報と通知は、目的を説明したあとユーザーの操作で初めて要求する。
struct OnboardingView: View {
    @Environment(\.colorScheme) private var colorScheme
    let environment: AppEnvironment
    let onFinish: () -> Void

    @State private var page = 0
    @State private var nickname = ""
    @State private var birthday = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date()
    @State private var reminderTime = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2000, month: 1, day: 1, hour: 7, minute: 30)) ?? Date()
    @State private var showCityPicker = false

    private var zodiac: Zodiac {
        Zodiac.from(date: birthday, calendar: KoyomiCalendar.japan)
    }

    var body: some View {
        ZStack {
            NightSkyBackground()
            VStack(spacing: KoyomiTheme.Spacing.l) {
                Spacer(minLength: KoyomiTheme.Spacing.xl)
                content
                Spacer()
                footer
            }
            .padding(KoyomiTheme.Spacing.l)
        }
        .sheet(isPresented: $showCityPicker) {
            CityPickerView { city in
                showCityPicker = false
                selectCity(city)
                page = 3
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch page {
        case 0: welcomePage
        case 1: profilePage
        case 2: locationPage
        default: reminderPage
        }
    }

    private var welcomePage: some View {
        VStack(spacing: KoyomiTheme.Spacing.m) {
            Text("Koyomi")
                .font(.system(.largeTitle, design: .serif).weight(.semibold))
            Text("気分と小さな行動を、わたしだけの暦に")
                .font(KoyomiTheme.bodyFont)
            Text("毎日ひとつ、自分にやさしい記録を。")
                .font(KoyomiTheme.headlineFont)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        .accessibilityIdentifier("onboarding.welcome")
    }

    private var profilePage: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                Text("あなたのことを、少しだけ教えてください")
                    .font(KoyomiTheme.headlineFont)
                TextField("ニックネーム（任意）", text: $nickname)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("onboarding.nickname")
                DatePicker(
                    "生年月日",
                    selection: $birthday,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .accessibilityIdentifier("onboarding.birthday")
                Text("あなたの星座は\(zodiac.japaneseName)です（\(zodiac.periodDescription)）")
                    .font(KoyomiTheme.bodyFont)
                Text("生年月日はこの端末の中だけに保存され、外部には送信されません。")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var locationPage: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                Text("今いる場所のお天気を、毎日の記録にそっと重ねます。")
                    .font(KoyomiTheme.headlineFont)
                Text("位置情報は「使用中のみ」お借りして、お天気の取得だけに使います。保存するのは都市名とお天気の要約だけです。")
                    .font(KoyomiTheme.bodyFont)
                KoyomiPrimaryButton(title: "次へ") {
                    Task { await requestLocation() }
                }
                .accessibilityIdentifier("onboarding.allowLocation")
                Button("都市を自分で選ぶ") { showCityPicker = true }
                    .frame(minHeight: KoyomiTheme.minimumTapTarget)
                    .accessibilityIdentifier("onboarding.chooseCity")
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var reminderPage: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                Text("毎朝、そっとお知らせしましょうか？")
                    .font(KoyomiTheme.headlineFont)
                DatePicker("リマインダーの時刻", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.compact)
                KoyomiPrimaryButton(title: "次へ") {
                    Task { await enableReminder() }
                }
                .accessibilityIdentifier("onboarding.enableReminder")
                Button("あとで") { finish(reminderEnabled: false) }
                    .frame(minHeight: KoyomiTheme.minimumTapTarget)
                    .accessibilityIdentifier("onboarding.skipReminder")
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var footer: some View {
        VStack(spacing: KoyomiTheme.Spacing.s) {
            if page < 2 {
                KoyomiPrimaryButton(title: page == 0 ? "はじめる" : "次へ") {
                    page += 1
                }
                .accessibilityIdentifier("onboarding.next")
            }
            HStack(spacing: KoyomiTheme.Spacing.xs) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index == page ? KoyomiTheme.strawberryMilk : KoyomiTheme.berryInk.opacity(0.2))
                        .frame(width: 6, height: 6)
                }
            }
            .accessibilityHidden(true)
        }
    }

    // MARK: - 保存と権限

    private func savePreferencesBase() -> UserPreferencesRecord {
        let preferences = environment.store.preferences()
        preferences.nickname = nickname
        preferences.birthday = birthday
        preferences.zodiac = zodiac
        environment.store.save()
        return preferences
    }

    private func requestLocation() async {
        let status = await environment.locationProvider.requestWhenInUseAuthorization()
        let preferences = savePreferencesBase()
        if status == .authorized {
            preferences.usesCurrentLocation = true
            preferences.selectedCityID = nil
            environment.store.save()
            page = 3
        } else {
            // 拒否されたときは権限を再要求せず、都市選択に切り替える。
            showCityPicker = true
        }
    }

    private func selectCity(_ city: City) {
        let preferences = savePreferencesBase()
        preferences.usesCurrentLocation = false
        preferences.selectedCityID = city.id
        environment.store.save()
    }

    private func enableReminder() async {
        let granted = await environment.notificationScheduler.requestAuthorization()
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: reminderTime)
        if granted {
            await environment.notificationScheduler.scheduleDailyReminder(
                hour: components.hour ?? 7,
                minute: components.minute ?? 30
            )
        }
        finish(reminderEnabled: granted, components: components)
    }

    private func finish(reminderEnabled: Bool, components: DateComponents? = nil) {
        let preferences = savePreferencesBase()
        preferences.reminderEnabled = reminderEnabled
        if let components {
            preferences.reminderHour = components.hour ?? 7
            preferences.reminderMinute = components.minute ?? 30
        }
        if preferences.selectedCityID == nil && !preferences.usesCurrentLocation {
            // 位置も都市も未設定なら、天気なしでも使えるよう東京を既定にする。
            preferences.selectedCityID = City.tokyo.id
        }
        preferences.onboardingCompleted = true
        environment.store.save()
        onFinish()
    }
}
