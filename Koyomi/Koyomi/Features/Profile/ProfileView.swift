import SwiftUI
import KoyomiCore

/// プロフィール・都市・リマインダー・プライバシー・免責事項。
struct ProfileView: View {
    let environment: AppEnvironment
    let onReset: () -> Void

    @State private var nickname = ""
    @State private var birthday = Date()
    @State private var usesCurrentLocation = false
    @State private var selectedCityID = City.tokyo.id
    @State private var reminderEnabled = false
    @State private var reminderTime = Date()
    @State private var showDeleteConfirmation = false
    @State private var showCityPicker = false
    @State private var adMob = AdMobProvider.shared

    private var zodiac: Zodiac { Zodiac.from(date: birthday, calendar: KoyomiCalendar.japan) }

    var body: some View {
        NavigationStack {
            Form {
                Section("わたし") {
                    TextField("ニックネーム（任意）", text: $nickname)
                    DatePicker("生年月日", selection: $birthday, in: ...Date(), displayedComponents: .date)
                    Text("星座：\(zodiac.japaneseName)")
                }

                Section("お天気") {
                    Toggle("現在地のお天気を使う", isOn: $usesCurrentLocation)
                    Button {
                        showCityPicker = true
                    } label: {
                        HStack {
                            Text("都市")
                            Spacer()
                            Text(City.city(id: selectedCityID)?.japaneseName ?? City.tokyo.japaneseName)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: KoyomiTheme.minimumTapTarget)
                    }
                    if environment.locationProvider.authorization == .denied {
                        Text("位置情報が使えない設定になっています。iOS の設定から変更できます。")
                            .font(KoyomiTheme.captionFont)
                    }
                }

                Section("リマインダー") {
                    Toggle("毎日のお知らせ", isOn: $reminderEnabled)
                    if reminderEnabled {
                        DatePicker("時刻", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                Section("Koyomi について") {
                    if adMob.privacyOptionsRequired {
                        Button("広告のプライバシー設定") {
                            Task { await adMob.presentPrivacyOptions() }
                        }
                    }
                    NavigationLink("プライバシーポリシー") { PrivacyPolicyView() }
                    NavigationLink("免責事項") { DisclaimerView() }
                }

                Section {
                    Button("すべてのデータを削除", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .accessibilityIdentifier("profile.deleteAll")
                } footer: {
                    Text("生年月日・履歴・お気に入り・都市の設定を、この端末から完全に削除します。")
                }
            }
            .tint(KoyomiTheme.strawberryMilk)
            .scrollContentBackground(.hidden)
            .background(
                LinearGradient(
                    colors: [KoyomiTheme.lavenderMilk.opacity(0.55), KoyomiTheme.vanilla],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("わたし")
            .onAppear(perform: loadPreferences)
            .onDisappear { Task { await savePreferences() } }
            .sheet(isPresented: $showCityPicker) {
                CityPickerView { city in
                    selectedCityID = city.id
                    usesCurrentLocation = false
                    showCityPicker = false
                }
            }
            .confirmationDialog(
                "すべてのデータを削除しますか？",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("削除する", role: .destructive) {
                    Task {
                        await environment.notificationScheduler.cancelDailyReminder()
                        environment.store.deleteAllData()
                        onReset()
                    }
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func loadPreferences() {
        let preferences = environment.store.preferences()
        nickname = preferences.nickname
        birthday = preferences.birthday
        usesCurrentLocation = preferences.usesCurrentLocation
        selectedCityID = preferences.selectedCityID ?? City.tokyo.id
        reminderEnabled = preferences.reminderEnabled
        reminderTime = Calendar(identifier: .gregorian).date(
            from: DateComponents(year: 2000, month: 1, day: 1, hour: preferences.reminderHour, minute: preferences.reminderMinute)
        ) ?? Date()
    }

    private func savePreferences() async {
        let preferences = environment.store.preferences()
        preferences.nickname = nickname
        preferences.birthday = birthday
        preferences.zodiac = zodiac
        preferences.selectedCityID = usesCurrentLocation ? nil : selectedCityID
        preferences.usesCurrentLocation = usesCurrentLocation
        let components = Calendar(identifier: .gregorian).dateComponents([.hour, .minute], from: reminderTime)
        preferences.reminderHour = components.hour ?? 7
        preferences.reminderMinute = components.minute ?? 30

        if reminderEnabled {
            // ユーザーが自分でオンにしたときだけ通知権限を要求する。
            let granted = preferences.reminderEnabled
                ? true
                : await environment.notificationScheduler.requestAuthorization()
            preferences.reminderEnabled = granted
            if granted {
                await environment.notificationScheduler.scheduleDailyReminder(
                    hour: preferences.reminderHour,
                    minute: preferences.reminderMinute
                )
            }
        } else {
            preferences.reminderEnabled = false
            await environment.notificationScheduler.cancelDailyReminder()
        }
        environment.store.save()
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            Text(KoyomiLegalText.privacyPolicy)
                .font(KoyomiTheme.bodyFont)
                .padding(KoyomiTheme.Spacing.m)
        }
        .navigationTitle("プライバシーポリシー")
    }
}

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            Text(KoyomiLegalText.disclaimer)
                .font(KoyomiTheme.bodyFont)
                .padding(KoyomiTheme.Spacing.m)
        }
        .navigationTitle("免責事項")
    }
}
