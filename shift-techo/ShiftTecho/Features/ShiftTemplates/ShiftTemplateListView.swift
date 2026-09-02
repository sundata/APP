import SwiftUI
import ShiftTechoCore

/// テンプレートの一覧・並べ替え・アーカイブ。
@MainActor
struct ShiftTemplateListView: View {
    private let environment: AppEnvironment

    @State private var draft: ShiftTemplateDraft?
    @State private var revision = 0
    @State private var showsPremium = false

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    private var store: ShiftTechoStore { environment.store }

    private var active: [ShiftTemplate] {
        store.activeTemplates().map(\.template)
    }

    private var archived: [ShiftTemplate] {
        store.allTemplates().filter(\.isArchived).map(\.template)
    }

    private var canAddForPlan: Bool {
        store.canAddTemplate && (environment.entitlements.isPro || active.count < 5)
    }

    var body: some View {
        List {
            Section {
                if active.isEmpty {
                    Text("シフトがありません。右上の＋から追加しましょう。")
                        .font(ShiftTechoTheme.captionFont)
                        .foregroundStyle(.secondary)
                }
                ForEach(active) { template in
                    Button {
                        draft = ShiftTemplateDraft(templateID: template.id, definition: template.definition, isNew: false)
                    } label: {
                        ShiftTemplateRow(definition: template.definition)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button("アーカイブ") {
                            store.archiveTemplate(id: template.id)
                            revision += 1
                        }
                        .tint(.orange)
                    }
                }
                .onMove { indices, destination in
                    var ids = active.map(\.id)
                    ids.move(fromOffsets: indices, toOffset: destination)
                    store.moveTemplates(ids)
                    revision += 1
                }
            } header: {
                Text(environment.entitlements.isPro ? "使用中（プレミアム）" : "使用中（無料版は5件まで）")
            } footer: {
                Text("すでに登録したシフトに使われているテンプレートは削除できません。アーカイブすると新規登録の候補から外れ、過去の記録はそのまま残ります。")
            }

            if !archived.isEmpty {
                Section("アーカイブ") {
                    ForEach(archived) { template in
                        HStack {
                            ShiftTemplateRow(definition: template.definition, isArchived: true)
                            Spacer(minLength: 0)
                            Button("戻す") {
                                if canAddForPlan {
                                    store.unarchiveTemplate(id: template.id)
                                    revision += 1
                                } else if !environment.entitlements.isPro {
                                    showsPremium = true
                                }
                            }
                            .font(ShiftTechoTheme.captionFont)
                            .disabled(!store.canAddTemplate)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.deleteTemplate(id: archived[index].id)
                        }
                        revision += 1
                    }
                }
            }
        }
        .id(revision)
        .navigationTitle("シフトテンプレート")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if canAddForPlan {
                        draft = ShiftTemplateDraft.newWorkShift()
                    } else if !environment.entitlements.isPro {
                        showsPremium = true
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!store.canAddTemplate)
                .accessibilityIdentifier("addTemplateButton")
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(item: $draft) { draft in
            ShiftTemplateEditorView(draft: draft) { updated in
                if updated.isNew {
                    store.addTemplate(updated.definition)
                } else {
                    store.updateTemplate(id: updated.templateID, definition: updated.definition)
                }
                revision += 1
            }
        }
        .sheet(isPresented: $showsPremium) {
            PremiumPaywallView(entitlements: environment.entitlements)
        }
    }
}
