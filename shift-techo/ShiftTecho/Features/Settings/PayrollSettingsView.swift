import SwiftUI
import ShiftTechoCore

/// 給与ルールの編集。金額は非負整数、割増は 0〜200%。
@MainActor
struct PayrollSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    private let store: ShiftTechoStore

    @State private var wageText: String
    @State private var nightPremiumPercent: Int
    @State private var overtimePremiumPercent: Int
    @State private var nightStartMinute: Int
    @State private var nightEndMinute: Int
    @State private var standardDailyMinutes: Int
    @State private var transportText: String
    @State private var hidesAmountsWhenInactive: Bool
    @FocusState private var focusedField: Field?
    @State private var saveErrorMessage: String?

    private enum Field { case wage, transport }

    init(store: ShiftTechoStore) {
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
                    .focused($focusedField, equals: .wage)
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
                    .focused($focusedField, equals: .transport)
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
                    .font(ShiftTechoTheme.captionFont)
                    .foregroundStyle(.secondary)
            }

            Section {
                ShiftTechoPrimaryButton(title: "保存する") { saveAndDismiss() }
                    .accessibilityIdentifier("savePayrollSettingsBottomButton")
            }
        }
        .navigationTitle("給与ルール")
        .onAppear { loadSavedValues() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("保存") {
                    saveAndDismiss()
                }
                .fontWeight(.semibold)
                .accessibilityIdentifier("savePayrollSettingsButton")
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完了") { focusedField = nil }
            }
        }
        .onDisappear { persist() }
        .alert("保存できませんでした", isPresented: Binding(
            get: { saveErrorMessage != nil },
            set: { if !$0 { saveErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { saveErrorMessage = nil }
        } message: {
            Text(saveErrorMessage ?? "もう一度お試しください。")
        }
    }

    private func saveAndDismiss() {
        focusedField = nil
        if persist() { dismiss() }
    }

    @discardableResult
    private func persist() -> Bool {
        let wage = integer(from: wageText)
        let transport = integer(from: transportText) ?? 0
        store.updatePayrollSettings(
            PayrollSettings(
                hourlyWageYen: wage,
                nightPremiumBasisPoints: nightPremiumPercent * 100,
                overtimePremiumBasisPoints: overtimePremiumPercent * 100,
                nightStartMinute: nightStartMinute,
                nightEndMinute: nightEndMinute,
                standardDailyMinutes: standardDailyMinutes,
                transportAllowancePerWorkdayYen: transport
            )
        )
        let record = store.settings()
        record.hidesAmountsWhenInactive = hidesAmountsWhenInactive
        let saved = store.settings().payrollSettings
        guard store.save(),
              saved.hourlyWageYen == wage,
              saved.transportAllowancePerWorkdayYen == transport else {
            saveErrorMessage = store.lastSaveError ?? "入力した時給を確認できませんでした。"
            return false
        }
        return true
    }

    /// ASCII・全角など、数字として認識できる文字を安全に整数へ変換する。
    private func integer(from text: String) -> Int? {
        let digits = text.compactMap(\.wholeNumberValue)
        guard !digits.isEmpty else { return nil }
        return digits.reduce(0) { partial, digit in
            let (multiplied, overflow1) = partial.multipliedReportingOverflow(by: 10)
            let (added, overflow2) = multiplied.addingReportingOverflow(digit)
            return overflow1 || overflow2 ? Int.max : added
        }
    }

    private func loadSavedValues() {
        let record = store.settings()
        let settings = record.payrollSettings
        wageText = settings.hourlyWageYen.map(String.init) ?? ""
        nightPremiumPercent = settings.nightPremiumBasisPoints / 100
        overtimePremiumPercent = settings.overtimePremiumBasisPoints / 100
        nightStartMinute = settings.nightStartMinute
        nightEndMinute = settings.nightEndMinute
        standardDailyMinutes = settings.standardDailyMinutes
        transportText = String(settings.transportAllowancePerWorkdayYen)
        hidesAmountsWhenInactive = record.hidesAmountsWhenInactive
    }
}
