import SwiftUI
import ShiftTechoCore

/// 単日のシフト編集シート。テンプレートを選ぶだけで保存できる。
@MainActor
struct DayShiftEditorView: View {
    @Environment(\.dismiss) private var dismiss

    private let environment: AppEnvironment
    private let dayKey: String
    /// 保存・削除の完了通知（Undo 表示用のタイトルを渡す）。
    private let onChange: (String) -> Void

    @State private var selectedTemplateID: UUID?
    @State private var note: String
    @State private var hasExistingEntry: Bool

    init(environment: AppEnvironment, dayKey: String, onChange: @escaping (String) -> Void) {
        self.environment = environment
        self.dayKey = dayKey
        self.onChange = onChange
        let entry = environment.store.entry(dayKey: dayKey)
        _selectedTemplateID = State(initialValue: entry?.templateID)
        _note = State(initialValue: entry?.note ?? "")
        _hasExistingEntry = State(initialValue: entry != nil)
    }

    private var store: ShiftTechoStore { environment.store }
    private var templates: [ShiftTemplate] { store.activeTemplates().map(\.template) }

    private var dateText: String {
        guard let date = ShiftTechoCalendar.date(fromDayKey: dayKey) else { return dayKey }
        return ShiftTechoCalendar.displayDate(for: date)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(dateText)
                        .font(ShiftTechoTheme.headlineFont)
                        .accessibilityIdentifier("editorDateText")
                    if let holiday = JapaneseHolidayCalendar.holidayName(dayKey: dayKey) {
                        Text(holiday)
                            .font(ShiftTechoTheme.captionFont)
                            .foregroundStyle(ShiftTechoTheme.sunday)
                    }
                }

                Section("シフト") {
                    if templates.isEmpty {
                        Text("設定タブでシフトテンプレートを追加してください。")
                            .font(ShiftTechoTheme.captionFont)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(templates) { template in
                        Button {
                            selectedTemplateID = template.id
                        } label: {
                            HStack {
                                ShiftTemplateRow(definition: template.definition)
                                if selectedTemplateID == template.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(ShiftTechoTheme.accent)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("templateOption-\(template.definition.name)")
                        .accessibilityAddTraits(selectedTemplateID == template.id ? [.isSelected] : [])
                    }
                }

                Section {
                    TextField("メモ（任意・端末内のみ）", text: $note, axis: .vertical)
                        .lineLimit(1...3)
                        .onChange(of: note) { _, newValue in
                            if newValue.count > ShiftAssignment.noteLengthLimit {
                                note = String(newValue.prefix(ShiftAssignment.noteLengthLimit))
                            }
                        }
                        .accessibilityIdentifier("noteField")
                } footer: {
                    Text("\(note.count)/\(ShiftAssignment.noteLengthLimit) 文字。メモは共有画像や通知には表示されません。")
                }

                Section {
                    ShiftTechoPrimaryButton(title: "保存", isEnabled: selectedTemplateID != nil) {
                        save()
                    }
                    .accessibilityIdentifier("saveShiftButton")

                    if hasExistingEntry {
                        Button("このシフトを削除", role: .destructive) {
                            store.deleteEntry(dayKey: dayKey)
                            onChange("シフトを削除しました")
                            dismiss()
                        }
                        .frame(maxWidth: .infinity, minHeight: ShiftTechoTheme.minimumTapTarget)
                        .accessibilityIdentifier("deleteShiftButton")
                    }
                }
            }
            .navigationTitle("シフトを登録")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        guard let id = selectedTemplateID, let template = store.template(id: id) else { return }
        store.assign(
            dayKey: dayKey,
            templateID: template.id,
            definition: template.definition,
            note: note,
            undoTitle: hasExistingEntry ? "シフトを更新しました" : "シフトを登録しました"
        )
        onChange(hasExistingEntry ? "シフトを更新しました" : "シフトを登録しました")
        dismiss()
    }
}
