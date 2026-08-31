import SwiftUI
import UIKit
import KoyomiCore

/// リマインダー設定。スイッチを入れたときだけ通知権限を要求する。
@MainActor
struct ReminderSettingsView: View {
    private let environment: AppEnvironment

    @State private var settings: ReminderSettings
    @State private var permission: NotificationPermission = .notDetermined

    init(environment: AppEnvironment) {
        self.environment = environment
        _settings = State(initialValue: environment.store.settings().reminderSettings)
    }

    private var store: KoyomiStore { environment.store }
    private var isDenied: Bool { permission == .denied }

    var body: some View {
        Form {
            if isDenied {
                Section {
                    VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                        Text("通知が許可されていません。iOS の「設定」＞「通知」＞ Koyomi で許可してください。")
                            .font(KoyomiTheme.captionFont)
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            Link("設定を開く", destination: url)
                                .frame(minHeight: KoyomiTheme.minimumTapTarget)
                                .accessibilityIdentifier("openSystemSettingsLink")
                        }
                    }
                }
            }

            Section {
                Toggle("毎月の入力リマインダー", isOn: monthlyBinding)
                    .accessibilityIdentifier("monthlyReminderToggle")
                if settings.monthlyReminderEnabled {
                    Stepper("毎月 \(settings.monthlyReminderDay) 日", value: $settings.monthlyReminderDay, in: 1...28)
                        .accessibilityIdentifier("monthlyReminderDayStepper")
                    MinutePicker(title: "通知時刻", minute: $settings.monthlyReminderMinuteOfDay)
                }
            } footer: {
                Text("翌月のシフトを入力し忘れないようにお知らせします。")
            }

            Section {
                Toggle("あすのシフト通知", isOn: nextShiftBinding)
                    .accessibilityIdentifier("nextShiftReminderToggle")
                if settings.nextShiftReminderEnabled {
                    MinutePicker(title: "前日の通知時刻", minute: $settings.nextShiftReminderMinuteOfDay)
                }
            } footer: {
                Text("通知には給与とメモは表示されません。夜勤は開始日を本文でお知らせします。")
            }
        }
        .navigationTitle("リマインダー")
        .task { permission = await environment.notificationScheduler.permission() }
        .onChange(of: settings) { _, _ in persist() }
    }

    private var monthlyBinding: Binding<Bool> {
        Binding(
            get: { settings.monthlyReminderEnabled },
            set: { newValue in enable(newValue, keyPath: \.monthlyReminderEnabled) }
        )
    }

    private var nextShiftBinding: Binding<Bool> {
        Binding(
            get: { settings.nextShiftReminderEnabled },
            set: { newValue in enable(newValue, keyPath: \.nextShiftReminderEnabled) }
        )
    }

    /// オンにするときだけ権限を要求する。拒否されたらスイッチは戻す。
    private func enable(_ newValue: Bool, keyPath: WritableKeyPath<ReminderSettings, Bool>) {
        guard newValue else {
            settings[keyPath: keyPath] = false
            return
        }
        Task {
            let current = await environment.notificationScheduler.permission()
            permission = current
            switch current {
            case .granted:
                settings[keyPath: keyPath] = true
            case .notDetermined:
                let granted = await environment.notificationScheduler.requestAuthorization()
                permission = granted ? .granted : .denied
                settings[keyPath: keyPath] = granted
            case .denied:
                settings[keyPath: keyPath] = false
            }
        }
    }

    private func persist() {
        store.updateReminderSettings(settings)
        Task { await environment.refreshNotifications() }
    }
}
