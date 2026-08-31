import SwiftUI
import KoyomiCore

/// 編集中のテンプレート。新規作成でも既存編集でも同じ画面を使う。
struct ShiftTemplateDraft: Identifiable, Hashable {
    var templateID: UUID
    var definition: ShiftDefinition
    var isNew: Bool

    var id: UUID { templateID }

    static func newWorkShift() -> ShiftTemplateDraft {
        ShiftTemplateDraft(
            templateID: UUID(),
            definition: ShiftDefinition(name: "", kind: .work, startMinute: 9 * 60, endMinute: 18 * 60),
            isNew: true
        )
    }
}

/// テンプレート 1 行の表示。色だけでなく名前と時間も出す。
struct ShiftTemplateRow: View {
    let definition: ShiftDefinition
    var isArchived = false

    var body: some View {
        HStack(spacing: KoyomiTheme.Spacing.m) {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(KoyomiTheme.color(definition.color))
                .frame(width: 12, height: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(definition.name.isEmpty ? "名称未設定" : definition.name)
                    .font(KoyomiTheme.bodyFont.weight(.medium))
                Text(subtitle)
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isArchived {
                Text("アーカイブ")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: KoyomiTheme.minimumTapTarget)
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        guard definition.kind == .work else { return "休み・給与なし" }
        let range = definition.timeRangeText ?? "時間未設定"
        let crossing = definition.crossesMidnight ? "（翌日まで）" : ""
        return "\(range)\(crossing)・休憩\(definition.breakMinutes)分・実働\(PayrollCalculator.durationText(minutes: definition.billableMinutes))"
    }
}

/// テンプレートの作成・編集フォーム。
struct ShiftTemplateEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var draft: ShiftTemplateDraft
    private let onSave: (ShiftTemplateDraft) -> Void

    init(draft: ShiftTemplateDraft, onSave: @escaping (ShiftTemplateDraft) -> Void) {
        _draft = State(initialValue: draft)
        self.onSave = onSave
    }

    private var definition: ShiftDefinition { draft.definition }

    var body: some View {
        NavigationStack {
            Form {
                Section("名前") {
                    TextField("例：夜勤", text: Binding(
                        get: { definition.name },
                        set: { draft.definition.name = String($0.prefix(ShiftDefinition.nameLengthLimit)) }
                    ))
                    .accessibilityIdentifier("templateNameField")
                    Text("1〜\(ShiftDefinition.nameLengthLimit)文字で入力してください。")
                        .font(KoyomiTheme.captionFont)
                        .foregroundStyle(.secondary)
                }

                Section("種類") {
                    Picker("種類", selection: Binding(
                        get: { definition.kind },
                        set: { newKind in
                            draft.definition = ShiftDefinition(
                                name: definition.name,
                                kind: newKind,
                                startMinute: newKind == .work ? (definition.startMinute ?? 9 * 60) : nil,
                                endMinute: newKind == .work ? (definition.endMinute ?? 18 * 60) : nil,
                                crossesMidnight: newKind == .work ? definition.crossesMidnight : false,
                                breakMinutes: newKind == .work ? definition.breakMinutes : 0,
                                color: definition.color
                            )
                        }
                    )) {
                        ForEach(ShiftKind.allCases, id: \.self) { kind in
                            Text(kind.japaneseName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("templateKindPicker")
                }

                if definition.kind == .work {
                    Section("時間") {
                        MinutePicker(title: "開始", minute: Binding(
                            get: { definition.startMinute ?? 9 * 60 },
                            set: { draft.definition.startMinute = $0 }
                        ))
                        MinutePicker(title: "終了", minute: Binding(
                            get: { definition.endMinute ?? 18 * 60 },
                            set: { draft.definition.endMinute = $0 }
                        ))
                        Toggle("翌日にまたぐ", isOn: Binding(
                            get: { definition.crossesMidnight },
                            set: { draft.definition.crossesMidnight = $0 }
                        ))
                        .accessibilityIdentifier("templateCrossesMidnightToggle")
                        Stepper(
                            "休憩 \(definition.breakMinutes) 分",
                            value: Binding(
                                get: { definition.breakMinutes },
                                set: { draft.definition.breakMinutes = min(max($0, 0), ShiftDefinition.breakMinutesRange.upperBound) }
                            ),
                            in: ShiftDefinition.breakMinutesRange,
                            step: 15
                        )
                        LabeledContent("実働", value: PayrollCalculator.durationText(minutes: definition.billableMinutes))
                    }
                }

                Section("色") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: KoyomiTheme.Spacing.s) {
                        ForEach(ShiftColor.allCases, id: \.self) { color in
                            Button {
                                draft.definition.color = color
                            } label: {
                                VStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(KoyomiTheme.color(color))
                                        .frame(height: 32)
                                        .overlay {
                                            if definition.color == color {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                    Text(color.japaneseName)
                                        .font(KoyomiTheme.captionFont)
                                }
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: KoyomiTheme.minimumTapTarget)
                            .accessibilityLabel(color.japaneseName)
                            .accessibilityAddTraits(definition.color == color ? [.isSelected] : [])
                        }
                    }
                }
            }
            .navigationTitle(draft.isNew ? "シフトを追加" : "シフトを編集")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!definition.hasValidName)
                    .accessibilityIdentifier("templateSaveButton")
                }
            }
        }
    }
}

/// 15 分刻みの時刻ピッカー。DatePicker ではなく分の整数を扱う。
struct MinutePicker: View {
    let title: String
    @Binding var minute: Int

    private static let steps: [Int] = Array(stride(from: 0, to: 24 * 60, by: 15))

    var body: some View {
        Picker(title, selection: $minute) {
            ForEach(Self.steps, id: \.self) { value in
                Text(KoyomiCalendar.timeText(minuteOfDay: value)).tag(value)
            }
        }
    }
}
