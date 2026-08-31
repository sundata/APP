import SwiftUI
import KoyomiCore

/// 連続した日付にまとめて登録する。1 回で最大 62 日。
@MainActor
struct BulkShiftEntryView: View {
    @Environment(\.dismiss) private var dismiss

    private let environment: AppEnvironment
    private let onChange: (String) -> Void

    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedTemplateID: UUID?
    @State private var showsOverwriteConfirmation = false

    init(environment: AppEnvironment, initialDayKey: String, onChange: @escaping (String) -> Void) {
        self.environment = environment
        self.onChange = onChange
        let start = KoyomiCalendar.date(fromDayKey: initialDayKey) ?? environment.clock.now
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: start)
    }

    private var store: KoyomiStore { environment.store }
    private var templates: [ShiftTemplate] { store.activeTemplates().map(\.template) }

    private var dayKeys: [String] {
        KoyomiCalendar.dayKeys(from: startDate, to: endDate)
    }

    private var isOverLimit: Bool { dayKeys.count > KoyomiStore.bulkAssignmentLimit }

    private var overwriteCount: Int {
        store.existingAssignmentCount(dayKeys: dayKeys)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("期間") {
                    DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                        .environment(\.calendar, KoyomiCalendar.japan)
                        .accessibilityIdentifier("bulkStartDatePicker")
                    DatePicker("終了日", selection: $endDate, in: startDate..., displayedComponents: .date)
                        .environment(\.calendar, KoyomiCalendar.japan)
                        .accessibilityIdentifier("bulkEndDatePicker")
                    LabeledContent("対象日数", value: "\(dayKeys.count)日")
                        .accessibilityIdentifier("bulkDayCount")
                    if isOverLimit {
                        Text("一度に登録できるのは \(KoyomiStore.bulkAssignmentLimit) 日までです。期間を短くしてください。")
                            .font(KoyomiTheme.captionFont)
                            .foregroundStyle(KoyomiTheme.sunday)
                    }
                }

                Section("シフト") {
                    ForEach(templates) { template in
                        Button {
                            selectedTemplateID = template.id
                        } label: {
                            HStack {
                                ShiftTemplateRow(definition: template.definition)
                                if selectedTemplateID == template.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(KoyomiTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bulkTemplateOption-\(template.definition.name)")
                    }
                }

                Section {
                    KoyomiPrimaryButton(
                        title: "この期間に登録",
                        isEnabled: selectedTemplateID != nil && !isOverLimit && !dayKeys.isEmpty
                    ) {
                        if overwriteCount > 0 {
                            showsOverwriteConfirmation = true
                        } else {
                            apply()
                        }
                    }
                    .accessibilityIdentifier("bulkApplyButton")
                } footer: {
                    if overwriteCount > 0 {
                        Text("この期間には登録済みのシフトが \(overwriteCount) 日あります。上書きする前に確認します。")
                    } else {
                        Text("登録後は「元に戻す」で 1 回だけ取り消せます。")
                    }
                }
            }
            .navigationTitle("まとめて登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .confirmationDialog(
                "登録済みのシフト \(overwriteCount) 日を上書きします",
                isPresented: $showsOverwriteConfirmation,
                titleVisibility: .visible
            ) {
                Button("上書きする", role: .destructive) { apply() }
                    .accessibilityIdentifier("bulkOverwriteConfirmButton")
                Button("キャンセル", role: .cancel) {}
            }
        }
    }

    private func apply() {
        guard let id = selectedTemplateID, let template = store.template(id: id) else { return }
        let count = store.assignRange(dayKeys: dayKeys, templateID: template.id, definition: template.definition)
        onChange("\(count)日分を登録しました")
        dismiss()
    }
}
