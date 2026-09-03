import SwiftUI
import SwimFinderCore

struct AthleteHubView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    @State private var refreshToken = UUID()
    @State private var showsPlus = false

    private var athletes: [FavoriteLink] {
        store.favorites.filter { $0.kind == .athlete }.sorted {
            let left = athleteID($0), right = athleteID($1)
            return (store.preference(for: left)?.sortOrder ?? Int.max) < (store.preference(for: right)?.sortOrder ?? Int.max)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if athletes.isEmpty {
                    ContentUnavailableView("マイ選手はまだいません", systemImage: "person.crop.circle.badge.plus", description: Text("選手詳細の星を押すと、最新成績と成長をここでまとめて確認できます。"))
                        .accessibilityIdentifier("athleteHub.empty")
                } else {
                    Section {
                        ForEach(athletes) { link in
                            AthleteDashboardRow(link: link, refreshToken: refreshToken)
                        }
                    } header: { Text("見守っている選手") }

                    Section {
                        if environment.membership.isPlus {
                            NavigationLink {
                                FamilyComparisonView(links: athletes)
                            } label: {
                                Label("家族・チームの成長を見る", systemImage: "person.3.sequence.fill")
                            }
                            .accessibilityIdentifier("athleteHub.family")
                        } else {
                            Button { showsPlus = true } label: {
                                Label("家族・チームの成長を見る", systemImage: "lock.fill")
                            }
                            .accessibilityIdentifier("athleteHub.family.locked")
                        }

                        if environment.membership.isPlus {
                            NavigationLink {
                                RaceDayView(links: athletes)
                            } label: {
                                Label("大会当日モード", systemImage: "flag.checkered")
                            }
                            .accessibilityIdentifier("athleteHub.raceDay")
                        } else {
                            Button { showsPlus = true } label: {
                                Label("大会当日モード", systemImage: "lock.fill")
                            }
                            .accessibilityIdentifier("athleteHub.raceDay.locked")
                        }
                    } header: { Text("クイックアクセス") }
                }

                Section {
                    NavigationLink {
                        PlayerSearchView()
                    } label: {
                        Label("選手を検索して追加", systemImage: "person.crop.circle.badge.plus")
                    }
                    .accessibilityIdentifier("athleteHub.add")
                } footer: {
                    Text("検索結果から選手を開き、星を押すとマイ選手に追加されます。")
                }
            }
            .swimFinderScreen()
            .navigationTitle("マイ選手")
            .toolbar {
                if !athletes.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink { AthleteManagementView(links: athletes) } label: { Label("選手を管理", systemImage: "slider.horizontal.3") }
                            .accessibilityIdentifier("athleteHub.manage")
                    }
                }
            }
            .refreshable { refreshToken = UUID(); await checkUpdates() }
            .task { await checkUpdates() }
            .sheet(isPresented: $showsPlus) { PlusView() }
        }
    }

    private func athleteID(_ link: FavoriteLink) -> String { link.url.pathComponents.filter { $0 != "/" }.last ?? "" }

    private func checkUpdates() async {
        await environment.resultUpdateMonitor.check(athletes: athletes.compactMap { link in
            guard let id = link.url.pathComponents.filter({ $0 != "/" }).last else { return nil }
            return (id, link.title)
        })
    }
}

private struct AthleteDashboardRow: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    let link: FavoriteLink
    let refreshToken: UUID
    @State private var results: [SwimResult] = []
    @State private var loading = true
    @State private var loadFailed = false

    private var athleteID: String { link.url.pathComponents.filter { $0 != "/" }.last ?? "" }
    private var latest: SwimResult? { results.max { ($0.resultDate ?? "") < ($1.resultDate ?? "") } }
    private var bestCount: Int { ResultAnalytics.groupedPerformances(results).count }
    private var latestGroup: [SwimResult] {
        guard let latest else { return [] }
        return ResultAnalytics.groupedPerformances(results)[PerformanceEventKey(result: latest)] ?? []
    }
    private var latestDelta: Double? { ResultAnalytics.latestDelta(in: latestGroup) }
    private var goal: PerformanceGoal? { latest.flatMap { store.goal(athleteID: athleteID, eventName: $0.eventName) } }
    private var displayName: String { store.displayName(officialName: link.title, athleteID: athleteID) }

    var body: some View {
        NavigationLink {
            PlayerDetailView(player: PlayerSummary(id: athleteID, athleteID: athleteID, displayName: link.title))
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(displayName, systemImage: "person.crop.circle.fill").font(.headline)
                    Spacer()
                    Text("PB \(bestCount)種目").font(.caption.weight(.semibold)).foregroundStyle(SwimFinderTheme.poolBlue)
                }
                if displayName != link.title || !(store.preference(for: athleteID)?.groupName.isEmpty ?? true) {
                    Text([displayName == link.title ? nil : "公式名：\(link.title)", store.preference(for: athleteID)?.groupName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  "))
                        .font(.caption).foregroundStyle(.secondary)
                }
                if let latest {
                    Text("最新  \(latest.eventName)").font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Text(latest.time.isEmpty ? latest.remark ?? "—" : latest.time).font(.system(.title3, design: .monospaced).bold())
                        Spacer()
                        Text(latest.resultDate ?? latest.meetName).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(latest.meetName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    HStack(spacing: 12) {
                        if let latestDelta {
                            Label(latestDelta <= 0 ? String(format: "前回から %.2f秒短縮", abs(latestDelta)) : String(format: "前回から +%.2f秒", latestDelta), systemImage: latestDelta <= 0 ? "arrow.down.right" : "arrow.up.right")
                                .foregroundStyle(latestDelta <= 0 ? SwimFinderTheme.success : .secondary)
                        }
                        if let goal, let seconds = latest.seconds {
                            Label(seconds <= goal.targetSeconds ? "目標達成" : String(format: "目標まで %.2f秒", seconds - goal.targetSeconds), systemImage: "target")
                                .foregroundStyle(seconds <= goal.targetSeconds ? SwimFinderTheme.success : SwimFinderTheme.poolBlue)
                        }
                    }
                    .font(.caption.weight(.semibold))
                } else if loading {
                    ProgressView().controlSize(.small)
                } else if loadFailed {
                    Label("成績を読み込めませんでした。下に引いて再試行してください。", systemImage: "wifi.exclamationmark")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("athleteCard.error")
                } else {
                    Label("公開されている成績はまだありません", systemImage: "stopwatch")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("athleteCard.empty")
                }
            }
            .padding(.vertical, 5)
        }
        .task(id: refreshToken) { await load() }
    }

    private func load() async {
        loading = true; loadFailed = false
        do { results = try await environment.resultsProvider.playerResults(playerID: athleteID) }
        catch { results = []; loadFailed = true }
        loading = false
    }
}

private struct AthleteManagementView: View {
    @Environment(LocalStore.self) private var store
    @State var links: [FavoriteLink]
    @State private var editMode: EditMode = .inactive

    var body: some View {
        List {
            Section {
                ForEach(links) { link in
                    let id = link.url.pathComponents.filter { $0 != "/" }.last ?? ""
                    NavigationLink {
                        AthletePreferenceEditor(athleteID: id, officialName: link.title)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.displayName(officialName: link.title, athleteID: id)).font(.headline)
                            Text([link.title, store.preference(for: id)?.groupName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onMove { source, destination in
                    links.move(fromOffsets: source, toOffset: destination)
                    store.reorderAthletes(links.map { $0.url.pathComponents.filter { $0 != "/" }.last ?? "" })
                }
            } footer: { Text("編集から並べ替えできます。ニックネームとグループはこの端末だけに保存されます。") }
        }
        .swimFinderScreen()
        .navigationTitle("選手を管理")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .environment(\.editMode, $editMode)
    }
}

private struct AthletePreferenceEditor: View {
    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let athleteID: String
    let officialName: String
    @State private var nickname = ""
    @State private var groupName = ""

    var body: some View {
        Form {
            Section("公式情報") { LabeledContent("氏名", value: officialName) }
            Section {
                TextField("ニックネーム", text: $nickname).accessibilityIdentifier("athletePreference.nickname")
                TextField("グループ（例：家族、Aチーム）", text: $groupName).accessibilityIdentifier("athletePreference.group")
            } footer: { Text("公式名は変更されません。空欄にすると公式名を表示します。") }
        }
        .swimFinderScreen()
        .navigationTitle("表示設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") { store.setAthletePreference(athleteID: athleteID, nickname: nickname, groupName: groupName); dismiss() }
                    .accessibilityIdentifier("athletePreference.save")
            }
        }
        .onAppear {
            nickname = store.preference(for: athleteID)?.nickname ?? ""
            groupName = store.preference(for: athleteID)?.groupName ?? ""
        }
    }
}

struct FamilyComparisonView: View {
    @Environment(AppEnvironment.self) private var environment
    let links: [FavoriteLink]
    @State private var summaries: [GrowthSummary] = []

    var body: some View {
        List {
            Section {
                Text("順位ではなく、それぞれの選手が自分の過去からどれだけ前進したかを表示します。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(summaries) { summary in
                Section(summary.name) {
                    LabeledContent("記録のある種目", value: "\(summary.eventCount)種目")
                    LabeledContent("自己ベスト更新") {
                        Text(summary.improvement.map { String(format: "%.2f秒", $0) } ?? "比較データなし")
                            .foregroundStyle(summary.improvement == nil ? .secondary : SwimFinderTheme.success)
                    }
                    .accessibilityIdentifier("family.improvement")
                    if let event = summary.event { Text(event).font(.caption).foregroundStyle(.secondary) }
                }
            }
        }
        .swimFinderScreen()
        .navigationTitle("家族・チーム")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        var values: [GrowthSummary] = []
        for link in links {
            let id = link.url.pathComponents.filter { $0 != "/" }.last ?? ""
            let results = (try? await environment.resultsProvider.playerResults(playerID: id)) ?? []
            let groups = ResultAnalytics.groupedPerformances(results)
            let strongest = groups.compactMap { event, entries -> (String, Double)? in
                let sorted = ResultAnalytics.chronological(entries)
                guard let first = sorted.first?.seconds, let latest = sorted.last?.seconds, sorted.count > 1 else { return nil }
                return ("\(event.distance) \(event.style)（\(event.course.rawValue)）", max(0, first - latest))
            }.max { $0.1 < $1.1 }
            values.append(GrowthSummary(id: id, name: link.title, eventCount: groups.count, event: strongest?.0, improvement: strongest?.1))
        }
        summaries = values
    }
}

private struct GrowthSummary: Identifiable {
    let id: String, name: String
    let eventCount: Int
    let event: String?
    let improvement: Double?
}

struct RaceDayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    let links: [FavoriteLink]
    @State private var results: [SwimResult] = []
    @State private var selectedDate: String?
    @State private var showsAddPlan = false
    @State private var editingPlan: RacePlanItem?

    private var dates: [String] { Array(Set(results.compactMap(\.resultDate))).sorted(by: >) }
    private var shown: [SwimResult] { results.filter { selectedDate == nil || $0.resultDate == selectedDate } }

    var body: some View {
        List {
            if !store.racePlans.isEmpty {
                Section("当日プラン") {
                    ForEach(store.racePlans) { item in
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(item.scheduledAt, style: .time).font(.system(.headline, design: .monospaced))
                                Text(item.athleteName).font(.headline)
                                Spacer()
                                Menu(item.status.rawValue) {
                                    ForEach(RacePlanItem.Status.allCases, id: \.self) { status in
                                        Button(status.rawValue) { updateStatus(item, to: status) }
                                    }
                                }
                                Button { editingPlan = item } label: {
                                    Image(systemName: "pencil.circle")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(item.eventName)の予定を編集")
                                .accessibilityIdentifier("racePlan.edit")
                            }
                            if item.status != .finished {
                                TimelineView(.periodic(from: .now, by: 1)) { context in
                                    let remaining = item.scheduledAt.timeIntervalSince(context.date)
                                    Label(countdownText(remaining), systemImage: remaining > 0 ? "timer" : "exclamationmark.circle.fill")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(remaining > 15 * 60 ? SwimFinderTheme.poolBlue : .orange)
                                }
                                .accessibilityIdentifier("racePlan.countdown")
                            }
                            Text(item.eventName)
                            Text([item.meetName, item.heat.isEmpty ? nil : "\(item.heat)組", item.lane.isEmpty ? nil : "\(item.lane)レーン"].compactMap { $0 }.joined(separator: "  ·  "))
                                .font(.caption).foregroundStyle(.secondary)
                                .accessibilityIdentifier("racePlan.details")
                            if let minutes = item.reminderMinutes, item.status != .finished {
                                Label("\(minutes)分前に通知", systemImage: "bell.fill")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(SwimFinderTheme.poolBlue)
                                    .accessibilityIdentifier("racePlan.reminder")
                            }
                        }
                        .padding(.vertical, 3)
                    }
                    .onDelete(perform: deletePlans)
                }
            }
            Section {
                Picker("日付", selection: $selectedDate) {
                    Text("最新").tag(String?.none)
                    ForEach(dates, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                Text("組・泳道・予定時刻は、公式データに含まれる場合のみ表示します。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            ForEach(shown) { result in
                Section(result.playerName) {
                    Text(result.eventName).font(.headline)
                    LabeledContent("大会", value: result.meetName)
                    LabeledContent("ラウンド", value: result.roundLabel)
                    LabeledContent("泳道・予定時刻", value: "公式データ未提供")
                        .accessibilityIdentifier("raceDay.unavailableSchedule")
                    LabeledContent("結果", value: result.time.isEmpty ? result.remark ?? "未確定" : result.time)
                    if let rank = result.rank { LabeledContent("順位", value: rank) }
                }
            }
        }
        .swimFinderScreen()
        .navigationTitle("大会当日モード")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showsAddPlan = true } label: { Label("予定を追加", systemImage: "plus") }
                    .accessibilityIdentifier("raceDay.add")
            }
        }
        .sheet(isPresented: $showsAddPlan) { RacePlanEditorView(links: links, existingPlan: nil) }
        .sheet(item: $editingPlan) { item in RacePlanEditorView(links: links, existingPlan: item) }
        .task { await load() }
    }

    private func load() async {
        var all: [SwimResult] = []
        for link in links {
            let id = link.url.pathComponents.filter { $0 != "/" }.last ?? ""
            all += (try? await environment.resultsProvider.playerResults(playerID: id)) ?? []
        }
        results = all.sorted { ($0.resultDate ?? "") > ($1.resultDate ?? "") }
        selectedDate = dates.first
    }

    private func countdownText(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "予定時刻を過ぎています" }
        let minutes = Int(interval) / 60
        if minutes >= 60 { return "あと \(minutes / 60)時間\(minutes % 60)分" }
        return "あと \(minutes)分"
    }

    private func updateStatus(_ item: RacePlanItem, to status: RacePlanItem.Status) {
        store.setRacePlanStatus(item, status: status)
        if status == .finished {
            environment.resultUpdateMonitor.cancelRaceReminder(id: item.id)
        } else if item.reminderMinutes != nil {
            Task { _ = await environment.resultUpdateMonitor.scheduleRaceReminder(for: item) }
        }
    }

    private func deletePlans(at offsets: IndexSet) {
        let ids = store.deleteRacePlans(at: offsets)
        ids.forEach { environment.resultUpdateMonitor.cancelRaceReminder(id: $0) }
    }
}

private struct RacePlanEditorView: View {
    private enum FocusField: Hashable { case event, meet, heat, lane }
    @Environment(AppEnvironment.self) private var environment
    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let links: [FavoriteLink]
    let existingPlan: RacePlanItem?
    @State private var athleteURL = ""
    @State private var eventName = ""
    @State private var meetName = ""
    @State private var scheduledAt = Date()
    @State private var heat = ""
    @State private var lane = ""
    @State private var enablesReminder = false
    @State private var reminderMinutes = 30
    @State private var reminderFailed = false
    @FocusState private var focusedField: FocusField?

    var body: some View {
        NavigationStack {
            Form {
                Section("選手と種目") {
                    Picker("選手", selection: $athleteURL) {
                        Text("選択してください").tag("")
                        ForEach(links) { Text($0.title).tag($0.url.absoluteString) }
                    }
                    .accessibilityIdentifier("racePlan.athlete")
                    TextField("種目（例：100m 自由形）", text: $eventName)
                        .accessibilityIdentifier("racePlan.event")
                        .focused($focusedField, equals: .event)
                    TextField("大会名", text: $meetName)
                        .accessibilityIdentifier("racePlan.meet")
                        .focused($focusedField, equals: .meet)
                }
                Section("当日の予定") {
                    DatePicker("予定時刻", selection: $scheduledAt, in: (existingPlan == nil ? Date() : Date.distantPast)...)
                    TextField("組", text: $heat).keyboardType(.numberPad).focused($focusedField, equals: .heat).accessibilityIdentifier("racePlan.heat")
                    TextField("レーン", text: $lane).keyboardType(.numberPad).focused($focusedField, equals: .lane).accessibilityIdentifier("racePlan.lane")
                }
                Section {
                    Toggle("レース前に通知", isOn: $enablesReminder)
                        .accessibilityIdentifier("racePlan.enableReminder")
                    if enablesReminder {
                        Picker("通知タイミング", selection: $reminderMinutes) {
                            Text("15分前").tag(15)
                            Text("30分前").tag(30)
                            Text("60分前").tag(60)
                        }
                        .accessibilityIdentifier("racePlan.reminderMinutes")
                    }
                } footer: {
                    Text("通知は端末内で予約します。予定変更時はこのプランを作り直してください。")
                }
                Section { NoticeBanner(kind: .info, text: "手入力した予定はこの端末だけに保存され、公式記録とは区別して表示されます。") }
            }
            .swimFinderScreen()
            .navigationTitle(existingPlan == nil ? "当日予定を追加" : "当日予定を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { Task { await save() } }
                        .disabled(athleteURL.isEmpty || eventName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .accessibilityIdentifier("racePlan.save")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完了") { focusedField = nil }
                        .accessibilityIdentifier("racePlan.keyboardDone")
                }
            }
            .alert("通知を設定できませんでした", isPresented: $reminderFailed) {
                Button("OK") { dismiss() }
            } message: {
                Text("予定は保存しました。通知の許可と、通知予定時刻が現在より後かを確認してください。")
            }
            .onAppear { loadExistingPlan() }
        }
    }

    private func save() async {
        guard let link = links.first(where: { $0.url.absoluteString == athleteURL }) else { return }
        let id = link.url.pathComponents.filter { $0 != "/" }.last ?? ""
        let minutes = enablesReminder ? reminderMinutes : nil
        let item: RacePlanItem
        if let existingPlan {
            environment.resultUpdateMonitor.cancelRaceReminder(id: existingPlan.id)
            item = store.updateRacePlan(existingPlan, athleteID: id, athleteName: link.title, eventName: eventName, meetName: meetName, scheduledAt: scheduledAt, heat: heat, lane: lane, reminderMinutes: minutes)
        } else {
            item = store.addRacePlan(athleteID: id, athleteName: link.title, eventName: eventName, meetName: meetName, scheduledAt: scheduledAt, heat: heat, lane: lane, reminderMinutes: minutes)
        }
        if enablesReminder, !environment.isUITesting, !(await environment.resultUpdateMonitor.scheduleRaceReminder(for: item)) {
            reminderFailed = true
        } else {
            dismiss()
        }
    }

    private func loadExistingPlan() {
        guard let item = existingPlan else { return }
        athleteURL = links.first(where: { link in
            link.url.pathComponents.filter { $0 != "/" }.last == item.athleteID
        })?.url.absoluteString ?? ""
        eventName = item.eventName
        meetName = item.meetName
        scheduledAt = item.scheduledAt
        heat = item.heat
        lane = item.lane
        enablesReminder = item.reminderMinutes != nil
        reminderMinutes = item.reminderMinutes ?? 30
    }
}
