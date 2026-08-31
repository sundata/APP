import SwiftUI
import ShiftTechoCore

/// 初回ガイド（最大 3 ページ）。通知と位置情報の許可はここでは求めない。
@MainActor
struct OnboardingView: View {
    private let environment: AppEnvironment
    private let onFinished: () -> Void

    @State private var page = 0
    @State private var templates: [ShiftTemplate] = ShiftTemplate.defaults
    @State private var draft: ShiftTemplateDraft?
    @State private var wageText = ""

    init(environment: AppEnvironment, onFinished: @escaping () -> Void) {
        self.environment = environment
        self.onFinished = onFinished
    }

    var body: some View {
        ZStack {
            ShiftTechoBackground()
            VStack(spacing: ShiftTechoTheme.Spacing.l) {
                TabView(selection: $page) {
                    valuePage.tag(0)
                    templatePage.tag(1)
                    wagePage.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                footer
            }
            .padding(ShiftTechoTheme.Spacing.m)
        }
        .sheet(item: $draft) { draft in
            ShiftTemplateEditorView(draft: draft) { updated in
                apply(updated)
            }
        }
    }

    // MARK: - ページ

    private var valuePage: some View {
        VStack(spacing: ShiftTechoTheme.Spacing.m) {
            Spacer()
            Text("シフトを、もっとかんたんに。")
                .font(ShiftTechoTheme.titleFont)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("onboardingTitle")
            Text("早番・夜勤・休みをタップで登録して、その月の勤務時間と概算の給与をひと目で確認できます。")
                .font(ShiftTechoTheme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(ShiftTechoTheme.Spacing.m)
    }

    private var templatePage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ShiftTechoTheme.Spacing.m) {
                Text("シフトを用意しましょう")
                    .font(ShiftTechoTheme.titleFont)
                Text("よく使うシフトです。あとから設定でいつでも変更できます。")
                    .font(ShiftTechoTheme.captionFont)
                    .foregroundStyle(.secondary)

                ForEach(templates) { template in
                    Button {
                        draft = ShiftTemplateDraft(templateID: template.id, definition: template.definition, isNew: false)
                    } label: {
                        ShiftTechoCard {
                            ShiftTemplateRow(definition: template.definition)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    draft = ShiftTemplateDraft.newWorkShift()
                } label: {
                    Label("シフトを追加", systemImage: "plus.circle")
                        .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
                }
                .disabled(templates.count >= ShiftTemplate.activeLimit)
                .accessibilityIdentifier("onboardingAddTemplate")
            }
            .padding(.horizontal, ShiftTechoTheme.Spacing.xs)
        }
    }

    private var wagePage: some View {
        VStack(alignment: .leading, spacing: ShiftTechoTheme.Spacing.m) {
            Text("時給を設定しますか？")
                .font(ShiftTechoTheme.titleFont)
            Text("あとで設定してもかまいません。金額は端末内にだけ保存されます。")
                .font(ShiftTechoTheme.captionFont)
                .foregroundStyle(.secondary)
            ShiftTechoCard {
                HStack {
                    Text("基礎時給")
                    Spacer()
                    TextField("1200", text: $wageText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 120)
                        .accessibilityIdentifier("onboardingWageField")
                    Text("円")
                }
                .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
            }
            Text("表示金額は概算です。実際の給与・税金・社会保険料とは異なる場合があります。")
                .font(ShiftTechoTheme.captionFont)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(ShiftTechoTheme.Spacing.xs)
    }

    // MARK: - フッター

    private var footer: some View {
        VStack(spacing: ShiftTechoTheme.Spacing.s) {
            ShiftTechoPrimaryButton(title: page == 2 ? "はじめる" : "次へ") {
                if page < 2 {
                    withAnimation { page += 1 }
                } else {
                    finish(savingWage: true)
                }
            }
            .accessibilityIdentifier("onboardingPrimaryButton")

            Button(page == 2 ? "あとで設定する" : "スキップ") {
                finish(savingWage: false)
            }
            .font(ShiftTechoTheme.captionFont)
            .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
            .accessibilityIdentifier("onboardingSkip")
        }
    }

    // MARK: - 保存

    private func apply(_ updated: ShiftTemplateDraft) {
        guard updated.definition.hasValidName else { return }
        if let index = templates.firstIndex(where: { $0.id == updated.templateID }) {
            templates[index].definition = updated.definition
        } else if templates.count < ShiftTemplate.activeLimit {
            templates.append(
                ShiftTemplate(id: updated.templateID, definition: updated.definition, sortOrder: templates.count)
            )
        }
    }

    private func finish(savingWage: Bool) {
        let store = environment.store
        for (index, template) in templates.enumerated() {
            if let existing = store.template(id: template.id) {
                existing.definition = template.definition
                existing.sortOrder = index
            } else {
                _ = store.addTemplate(template.definition, id: template.id)
            }
        }
        if savingWage, let wage = Int(wageText.trimmingCharacters(in: .whitespaces)), wage >= 0 {
            var settings = store.settings().payrollSettings
            settings.hourlyWageYen = wage
            store.updatePayrollSettings(settings)
        }
        store.completeOnboarding()
        onFinished()
    }
}
