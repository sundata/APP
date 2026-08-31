import SwiftUI
import KoyomiCore

/// 給与ルールの編集。金額は非負整数、割増は 0〜200%。
@MainActor
struct PayrollSettingsView: View {
    private let store: KoyomiStore

    @State private var wageText: String
    @State private var nightPremiumPercent: Int
    @State private var overtimePremiumPercent: Int
    @State private var nightStartMinute: Int
    @State private var nightEndMinute: Int
    @State private var standardDailyMinutes: Int
    @State private var transportText: String
    @State private var hidesAmountsWhenInactive: Bool

    init(store: KoyomiStore) {
        self.store = store
        let record = store.settings()
        let settings = record.payrollSettings
        _wageText = State(initialValue: settings.hourlyWageYen.map(String.init) ?? "")
        _nightPremiumPercent = State(initialValue: settings.nightPremiumBasisPoints / 100)
        _overtimePremiumPercent = State(initialValue: settings.overtimePremiumBasisPoints / 100)
        _nightStartMinute = State(initialValue: settings.nightStartMinute)
        _nightEndMinute = State(initialValue: settings.nightEndMinute)
        _standardDailyMinutes = State(initialValue: settings.standardDailyMinutes)
        _transportText = State(initialValue: String(settings.transportAllowancePerWorkdayYen))
        _hidesAmountsWhenInactive = State(initialValue: record.hidesAmountsWhenInactive)
    }

    var body: some View {
        Form {
            Section {
                TextField("時給（円）", text: $wageText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("hourlyWageField")
            } header: {
                Text("基礎時給")
            } footer: {
                Text("空欄のままでも勤務時間は集計されます。")
            }

            Section("割増") {
                Stepper(
                    "深夜割増 \(nightPremiumPercent)%",
                    value: $nightPremiumPercent,
                    in: 0...200,
                    step: 5
                )
                .accessibilityIdentifier("nightPremiumStepper")
                MinutePicker(title: "深夜開始", minute: $nightStartMinute)
                MinutePicker(title: "深夜終了", minute: $nightEndMinute)
                Stepper(
                    "残業割増 \(overtimePremiumPercent)%",
                    value: $overtimePremiumPercent,
                    in: 0...200,
                    step: 5
                )
                .accessibilityIdentifier("overtimePremiumStepper")
                Stepper(
                    "1日の所定労働 \(PayrollCalculator.durationText(minutes: standardDailyMinutes))",
                    value: $standardDailyMinutes,
                    in: 0...(24 * 60),
                    step: 30
                )
                .accessibilityIdentifier("standardDailyStepper")
            }

            Section {
                TextField("交通費（円／勤務日）", text: $transportText)
                    .keyboardType(.numberPad)
                    .accessibilityIdentifier("transportField")
            } header: {
                Text("交通費")
            } footer: {
                Text("勤務日 1 日あたりの固定額として計算します。")
            }

            Section {
                Toggle("バックグラウンドで金額を隠す", isOn: $hidesAmountsWhenInactive)
                    .accessibilityIdentifier("hideAmountsToggle")
            } footer: {
                Text("アプリスイッチャーのスナップショットなどで金額が見えないようにします。")
            }

            Section {
                Text("表示金額は概算です。実際の給与・税金・社会保険料とは異なる場合があります。")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("給与ルール")
        .onDisappear { persist() }
    }

    private func persist() {
        let wage = Int(wageText.filter(\.isNumber))
        store.updatePayrollSettings(
            PayrollSettings(
                hourlyWageYen: wage,
                nightPremiumBasisPoints: nightPremiumPercent * 100,
                overtimePremiumBasisPoints: overtimePremiumPercent * 100,
                nightStartMinute: nightStartMinute,
                nightEndMinute: nightEndMinute,
                standardDailyMinutes: standardDailyMinutes,
                transportAllowancePerWorkdayYen: Int(transportText.filter(\.isNumber)) ?? 0
            )
        )
        let record = store.settings()
        record.hidesAmountsWhenInactive = hidesAmountsWhenInactive
        store.save()
    }
}
