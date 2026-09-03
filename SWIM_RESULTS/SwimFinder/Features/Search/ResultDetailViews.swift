import SwiftUI
import Charts
import UIKit
import SwimFinderCore

struct PlayerDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let player: PlayerSummary
    @State private var profile: PlayerProfile?
    @State private var results: [SwimResult] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @Environment(LocalStore.self) private var store
    @State private var selectedEvent = "すべて"
    @State private var selectedYear: Int?
    @State private var showsGoalEditor = false
    @State private var shareImage: UIImage?
    @State private var showsShareOptions = false
    @State private var showsPlus = false

    var body: some View {
        List {
            Section("選手") {
                LabeledContent("氏名", value: profile?.displayName ?? player.displayName)
                if let value = profile?.romanName { LabeledContent("ローマ字", value: value) }
                if let value = profile?.maskedCode { LabeledContent("競技者番号", value: value) }
                if let value = profile?.memberGroup ?? player.memberGroup { LabeledContent("加盟団体", value: value) }
                if let value = profile?.schoolClass ?? player.schoolClass { LabeledContent("学種", value: value) }
                if let value = profile?.gender ?? player.gender { LabeledContent("性別", value: value) }
            }
            Section("所属") {
                if let profile {
                    ForEach(profile.affiliations, id: \.self) { Label($0, systemImage: "building.2") }
                } else if let value = player.affiliation { Text(value) }
            }
            Section("これまでの成績") {
                if loading { ProgressView("読み込み中…") }
                else if let errorMessage { ContentUnavailableView("読み込めませんでした", systemImage: "wifi.exclamationmark", description: Text(errorMessage)) }
                else if results.isEmpty { ContentUnavailableView("成績はありません", systemImage: "stopwatch") }
                else {
                    Picker("種目", selection: $selectedEvent) {
                        Text("すべて").tag("すべて")
                        ForEach(eventNames, id: \.self) { Text($0).tag($0) }
                    }
                    Picker("年度", selection: $selectedYear) {
                        Text("すべて").tag(Int?.none)
                        ForEach(years, id: \.self) { Text(verbatim: "\($0)年度").tag(Int?.some($0)) }
                    }
                }
            }

            if !filteredResults.isEmpty, selectedEvent == "すべて" {
                Section("サマリー") {
                    Label("種目を選択すると、同じ種目内の自己ベスト・前回との差・推移を確認できます。", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("player.selectEventHint")
                }
            }

            if !filteredResults.isEmpty, selectedEvent != "すべて" {
                Section("サマリー") {
                    if let bestResult {
                        LabeledContent("自己ベスト") {
                            Text(bestResult.time).font(.system(.headline, design: .monospaced)).foregroundStyle(SwimFinderTheme.officialBlue)
                        }
                    }
                    if let latestDelta {
                        LabeledContent("前回との差") {
                            Text(deltaText(latestDelta))
                                .font(.system(.body, design: .monospaced).weight(.semibold))
                                .foregroundStyle(latestDelta <= 0 ? SwimFinderTheme.success : .orange)
                        }
                    }
                    if environment.membership.isPlus, let goal = store.goal(athleteID: player.athleteID, eventName: selectedEvent), let latest = chronological.last?.seconds {
                        LabeledContent("目標タイム") { Text(formatTime(goal.targetSeconds)).font(.system(.body, design: .monospaced)) }
                        LabeledContent(latest <= goal.targetSeconds ? "達成" : "目標まで") {
                            Text(latest <= goal.targetSeconds ? "おめでとう！" : String(format: "あと %.2f秒", latest - goal.targetSeconds))
                                .foregroundStyle(latest <= goal.targetSeconds ? SwimFinderTheme.success : SwimFinderTheme.poolBlue)
                                .accessibilityIdentifier("player.goalProgress")
                        }
                    }
                    if environment.membership.isPlus, chartResults.count >= 2 {
                        Chart(chartResults) { result in
                            if let seconds = result.seconds {
                                LineMark(x: .value("日付", result.resultDate ?? ""), y: .value("秒", seconds))
                                    .foregroundStyle(SwimFinderTheme.officialBlue)
                                PointMark(x: .value("日付", result.resultDate ?? ""), y: .value("秒", seconds))
                                    .foregroundStyle(SwimFinderTheme.aqua)
                            }
                        }
                        .frame(height: 180)
                        .chartYAxisLabel("タイム（秒）")
                        .accessibilityIdentifier("player.resultTrend")
                    } else if !environment.membership.isPlus, chartResults.count >= 2 {
                        Button { showsPlus = true } label: {
                            Label("詳細な推移をPlusで見る", systemImage: "lock.fill")
                        }
                        .accessibilityIdentifier("player.trend.locked")
                    }
                }
            }

            if selectedEvent != "すべて" {
                Section("目標と成長") {
                    if environment.membership.isPlus {
                        Button {
                            showsGoalEditor = true
                        } label: {
                            Label(store.goal(athleteID: player.athleteID, eventName: selectedEvent) == nil ? "目標タイムを設定" : "目標タイムを変更", systemImage: "target")
                        }
                        .accessibilityIdentifier("player.goal")

                        ForEach(milestones, id: \.self) { item in
                            Label(item, systemImage: "sparkles")
                                .foregroundStyle(SwimFinderTheme.navy)
                        }

                        if bestResult != nil {
                            Button {
                                showsShareOptions = true
                            } label: {
                                Label("成績カードを共有", systemImage: "square.and.arrow.up")
                            }
                            .accessibilityIdentifier("player.shareCard")
                        }
                    } else {
                        Button { showsPlus = true } label: {
                            Label("目標・成長・共有をPlusで利用", systemImage: "lock.fill")
                        }
                        .accessibilityIdentifier("player.growth.locked")
                    }
                }
            }

            ForEach(groupedResults, id: \.key) { group in
                Section(group.key) {
                    ForEach(group.values) { result in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.meetName).font(.subheadline.weight(.semibold))
                                    if let date = result.resultDate { Text(date).font(.caption).foregroundStyle(.secondary) }
                                }
                                Spacer()
                                Text(result.time).font(.system(.body, design: .monospaced).bold())
                            }
                            HStack {
                                Text(result.roundLabel)
                                if selectedEvent != "すべて", result.id == bestResult?.id { Label("ベスト", systemImage: "medal.fill").foregroundStyle(SwimFinderTheme.officialBlue) }
                                if let remark = result.remark { Text(remark).foregroundStyle(.blue) }
                            }.font(.caption).foregroundStyle(.secondary)
                        }.padding(.vertical, 3)
                    }
                }
            }
        }
        .swimFinderScreen()
        .navigationTitle(player.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = player.officialURL {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if store.isFavorite(url) {
                            store.removeFavorite(url: url).forEach { environment.resultUpdateMonitor.cancelRaceReminder(id: $0) }
                        }
                        else if !environment.membership.isPlus && watchedAthleteCount >= MembershipStore.freeAthleteLimit {
                            showsPlus = true
                        } else {
                            store.addFavorite(title: player.displayName, url: url)
                        }
                        syncWatchedAthletes()
                    } label: { Label("お気に入り", systemImage: store.isFavorite(url) ? "star.fill" : "star") }
                    .accessibilityIdentifier("player.favorite")
                }
            }
        }
        .sheet(isPresented: $showsPlus) { PlusView() }
        .task { await load() }
        .refreshable { await load() }
        .sheet(isPresented: $showsGoalEditor) {
            GoalEditorView(athleteID: player.athleteID, athleteName: player.displayName, eventName: selectedEvent)
        }
        .sheet(isPresented: $showsShareOptions) {
            if let bestResult {
                ShareOptionsView(playerName: player.displayName, result: bestResult) { hidesName, hidesMeet, hidesDate, hidesRank in
                    shareImage = makeShareImage(bestResult, hidesName: hidesName, hidesMeet: hidesMeet, hidesDate: hidesDate, hidesRank: hidesRank)
                }
            }
        }
        .sheet(isPresented: Binding(get: { shareImage != nil }, set: { if !$0 { shareImage = nil } })) {
            if let shareImage { ShareSheet(items: [shareImage]) }
        }
    }

    private func load() async {
        loading = true; errorMessage = nil
        do {
            async let fetchedProfile = environment.resultsProvider.playerProfile(playerID: player.athleteID)
            async let fetchedResults = environment.resultsProvider.playerResults(playerID: player.athleteID)
            (profile, results) = try await (fetchedProfile, fetchedResults)
        } catch let error as SwimResultsError { errorMessage = error.userMessage }
        catch { errorMessage = "データの読み込みに失敗しました。" }
        loading = false
    }

    private var eventNames: [String] { Array(Set(results.map(\.eventName))).sorted() }
    private var years: [Int] {
        Array(Set(results.compactMap { $0.resultDate.flatMap { Int($0.prefix(4)) } })).sorted(by: >)
    }
    private var filteredResults: [SwimResult] {
        results.filter {
            (selectedEvent == "すべて" || $0.eventName == selectedEvent) &&
            (selectedYear == nil || $0.resultDate.map { Int($0.prefix(4)) == selectedYear } == true)
        }
    }
    private var bestResult: SwimResult? { ResultAnalytics.personalBest(in: filteredResults) }
    private var chronological: [SwimResult] { ResultAnalytics.chronological(filteredResults) }
    private var latestDelta: Double? {
        guard chronological.count >= 2, let latest = chronological.last?.seconds, let previous = chronological.dropLast().last?.seconds else { return nil }
        return latest - previous
    }
    private var chartResults: [SwimResult] { selectedEvent == "すべて" ? [] : chronological }
    private var groupedResults: [(key: String, values: [SwimResult])] {
        Dictionary(grouping: filteredResults, by: \.eventName)
            .map { (key: $0.key, values: $0.value.sorted { ($0.resultDate ?? "") > ($1.resultDate ?? "") }) }
            .sorted { $0.key < $1.key }
    }
    private func deltaText(_ value: Double) -> String { String(format: "%+.2f秒", value) }
    private func syncWatchedAthletes() {
        let athletes = store.favorites.filter { $0.kind == .athlete }.compactMap { link -> (id: String, name: String)? in
            guard let id = link.url.pathComponents.filter({ $0 != "/" }).last else { return nil }
            return (id, link.title)
        }
        environment.resultUpdateMonitor.syncWatchedAthletes(athletes)
    }
    private var watchedAthleteCount: Int { store.favorites.filter { $0.kind == .athlete }.count }
    private func formatTime(_ seconds: Double) -> String {
        if seconds >= 60 { return String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60)) }
        return String(format: "%.2f", seconds)
    }
    private var milestones: [String] {
        guard let best = bestResult?.seconds else { return [] }
        var values = ["\(selectedEvent) の自己ベスト \(formatTime(best))"]
        if chronological.count == 1 { values.append("この種目への最初の一歩") }
        if let first = chronological.first?.seconds, first > best { values.append(String(format: "最初の記録から %.2f秒 前進", first - best)) }
        let streak = ResultAnalytics.consecutiveImprovementCount(in: filteredResults)
        if streak >= 2 { values.append("\(streak)大会連続でタイムを短縮") }
        if let latest = chronological.last, ResultAnalytics.isAnnualBest(latest, among: filteredResults) {
            values.append("\(latest.resultDate.map { String($0.prefix(4)) } ?? "今年")年度ベスト")
        }
        if let threshold = [180.0, 120, 90, 60, 30].first(where: { threshold in
            best < threshold && chronological.contains { result in (result.seconds ?? 0) >= threshold }
        }) {
            values.append("\(Int(threshold))秒の壁を突破")
        }
        return values
    }
    @MainActor private func makeShareImage(_ result: SwimResult, hidesName: Bool, hidesMeet: Bool, hidesDate: Bool, hidesRank: Bool) -> UIImage? {
        let renderer = ImageRenderer(content: ResultShareCard(playerName: hidesName ? "SWIMMER" : player.displayName, result: result, hidesMeet: hidesMeet, hidesDate: hidesDate, hidesRank: hidesRank))
        renderer.scale = 3
        return renderer.uiImage
    }
}

private struct GoalEditorView: View {
    @Environment(LocalStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let athleteID: String, athleteName: String, eventName: String
    @State private var value = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("例：51.50 または 1:02.30", text: $value)
                        .keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("goal.time")
                } header: {
                    Text(eventName)
                } footer: {
                    Text("この種目・水路だけの目標として保存します。")
                }
            }
            .swimFinderScreen()
            .navigationTitle("目標タイム")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        if let seconds = SwimTime.seconds(from: value) {
                            store.setGoal(athleteID: athleteID, athleteName: athleteName, eventName: eventName, targetSeconds: seconds)
                            dismiss()
                        }
                    }
                    .disabled(SwimTime.seconds(from: value) == nil)
                    .accessibilityIdentifier("goal.save")
                }
            }
            .onAppear { if let goal = store.goal(athleteID: athleteID, eventName: eventName) { value = format(goal.targetSeconds) } }
        }
    }

    private func format(_ seconds: Double) -> String {
        seconds >= 60 ? String(format: "%d:%05.2f", Int(seconds) / 60, seconds.truncatingRemainder(dividingBy: 60)) : String(format: "%.2f", seconds)
    }
}

private struct ResultShareCard: View {
    let playerName: String
    let result: SwimResult
    let hidesMeet: Bool
    let hidesDate: Bool
    let hidesRank: Bool

    var body: some View {
        ZStack {
            LinearGradient(colors: [SwimFinderTheme.navy, SwimFinderTheme.poolBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: 20) {
                Label("SWIMSCOPE", systemImage: "figure.pool.swim").font(.headline).foregroundStyle(SwimFinderTheme.aqua)
                Text(playerName).font(.title.bold()).foregroundStyle(.white)
                Text(result.eventName).font(.title3).foregroundStyle(.white.opacity(0.9))
                Text(result.time).font(.system(size: 54, weight: .bold, design: .monospaced)).foregroundStyle(.white)
                Divider().overlay(.white.opacity(0.4))
                Text(hidesMeet ? "大会名は非表示" : result.meetName).font(.headline).foregroundStyle(.white)
                Text([hidesDate ? nil : result.resultDate, result.roundLabel, hidesRank ? nil : result.rank.map { "\($0)位" }].compactMap { $0 }.joined(separator: "  ·  "))
                    .font(.subheadline).foregroundStyle(.white.opacity(0.8))
                Text("公式公開情報を参照した非公式カード").font(.caption).foregroundStyle(.white.opacity(0.65))
            }
            .padding(44)
        }
        .frame(width: 720, height: 720)
    }
}

private struct ShareOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var hidesName = false
    @State private var hidesMeet = false
    @State private var hidesDate = false
    @State private var hidesRank = false
    let playerName: String
    let result: SwimResult
    let completion: (Bool, Bool, Bool, Bool) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("プレビュー") {
                    ResultShareCard(playerName: hidesName ? "SWIMMER" : playerName, result: result, hidesMeet: hidesMeet, hidesDate: hidesDate, hidesRank: hidesRank)
                        .scaleEffect(0.39)
                        .frame(width: 280, height: 280)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("share.preview")
                }
                Section {
                    Toggle("選手名を隠す", isOn: $hidesName)
                    Toggle("大会名を隠す", isOn: $hidesMeet)
                    Toggle("日付を隠す", isOn: $hidesDate)
                    Toggle("順位を隠す", isOn: $hidesRank)
                } header: {
                    Text("プライバシー")
                } footer: { Text("所属名は成績カードに表示されません。共有前に内容を確認してください。") }
            }
            .swimFinderScreen()
            .navigationTitle("共有カード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("カードを作成") { completion(hidesName, hidesMeet, hidesDate, hidesRank); dismiss() }
                        .accessibilityIdentifier("share.create")
                }
            }
        }
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct MeetDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    let meet: MeetSummary
    @State private var events: [MeetEvent] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @Environment(LocalStore.self) private var store

    var body: some View {
        List {
            Section("大会情報") {
                if let value = meet.period { Label(value, systemImage: "calendar") }
                if let value = meet.venue { Label(value, systemImage: "mappin.and.ellipse") }
                if let value = meet.course { LabeledContent("水路", value: value) }
                if let value = meet.status { LabeledContent("状態", value: value) }
            }
            Section("競技結果") {
                if loading { ProgressView("読み込み中…") }
                else if let errorMessage { ContentUnavailableView("読み込めませんでした", systemImage: "wifi.exclamationmark", description: Text(errorMessage)) }
                else if events.isEmpty { ContentUnavailableView("結果はまだありません", systemImage: "list.bullet.rectangle") }
                else {
                    ForEach(events) { event in
                        NavigationLink {
                            EventResultsView(event: event)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title).font(.headline)
                                Text("\(event.date) · \(event.division)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .swimFinderScreen()
        .navigationTitle(meet.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let url = meet.officialURL {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        if store.isFavorite(url) { store.removeFavorite(url: url) }
                        else { store.addFavorite(title: meet.name, url: url) }
                    } label: { Label("お気に入り", systemImage: store.isFavorite(url) ? "star.fill" : "star") }
                    .accessibilityIdentifier("meet.favorite")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; errorMessage = nil
        do { events = try await environment.resultsProvider.meetEvents(meetID: meet.id) }
        catch let error as SwimResultsError { errorMessage = error.userMessage }
        catch { errorMessage = "データの読み込みに失敗しました。" }
        loading = false
    }
}

struct EventResultsView: View {
    @Environment(AppEnvironment.self) private var environment
    let event: MeetEvent
    @State private var results: [SwimResult] = []
    @State private var loading = true
    @State private var errorMessage: String?

    var body: some View {
        List {
            if loading { ProgressView("読み込み中…") }
            else if let errorMessage { ContentUnavailableView("読み込めませんでした", systemImage: "wifi.exclamationmark", description: Text(errorMessage)) }
            else if results.isEmpty { ContentUnavailableView("結果はまだありません", systemImage: "stopwatch") }
            else {
                ForEach(results) { result in
                    HStack(alignment: .top, spacing: 12) {
                        Text(result.rank ?? "—").font(.title3.bold()).frame(width: 34)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(result.playerName).font(.headline)
                            if let affiliation = result.affiliation { Text(affiliation).font(.caption).foregroundStyle(.secondary) }
                            if let remark = result.remark { Text(remark).font(.caption).foregroundStyle(.orange) }
                        }
                        Spacer()
                        Text(result.time).font(.system(.body, design: .monospaced).bold())
                    }
                    .padding(.vertical, 3)
                }
            }
        }
        .swimFinderScreen()
        .navigationTitle("\(event.title) · \(event.division)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true; errorMessage = nil
        do { results = try await environment.resultsProvider.eventResults(event: event) }
        catch let error as SwimResultsError { errorMessage = error.userMessage }
        catch { errorMessage = "データの読み込みに失敗しました。" }
        loading = false
    }
}
