import SwiftUI
import KoyomiCore

/// 履歴・お気に入り・連続日数。データは端末内のみ。
struct CalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let environment: AppEnvironment

    @State private var month: Date
    @State private var records: [String: FortuneRecord] = [:]
    @State private var moodRecords: [String: DailyMoodRecord] = [:]
    @State private var ritualRecords: [String: DailyRitualRecord] = [:]
    @State private var streak = 0
    @State private var selectedDayKey: String?
    @State private var showFavoritesOnly = false

    private var calendar: Calendar { KoyomiCalendar.japan }

    init(environment: AppEnvironment) {
        self.environment = environment
        _month = State(initialValue: environment.clock.now)
    }

    var body: some View {
        ZStack {
            NightSkyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                    streakCard
                    charmCollectionCard
                    monthCard
                    Toggle("お気に入りだけ表示", isOn: $showFavoritesOnly)
                        .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                    listCard
                }
                .padding(KoyomiTheme.Spacing.m)
            }
        }
        .onAppear(perform: reload)
        .sheet(item: Binding(
            get: { selectedDayKey.map(SelectedDay.init(dayKey:)) },
            set: { selectedDayKey = $0?.dayKey }
        )) { selection in
            if let record = records[selection.dayKey], let fortune = record.fortune {
                HistoryDetailView(record: record, fortune: fortune, moodRecord: moodRecords[selection.dayKey])
            }
        }
    }

    private struct SelectedDay: Identifiable {
        let dayKey: String
        var id: String { dayKey }
    }

    private var streakCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                Text("つづけて見ている日数")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
                Text("\(streak)日")
                    .font(KoyomiTheme.titleFont)
                Text("お休みの日があっても大丈夫。またいつでも戻ってきてください。")
                    .font(KoyomiTheme.captionFont)
                if streak > 0 {
                    Text(streakMessage)
                        .font(KoyomiTheme.bodyFont.weight(.semibold))
                        .padding(.top, KoyomiTheme.Spacing.xs)
                }
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var monthCard: some View {
        GlassCard {
            VStack(spacing: KoyomiTheme.Spacing.s) {
                HStack {
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .frame(width: KoyomiTheme.minimumTapTarget, height: KoyomiTheme.minimumTapTarget)
                    }
                    .accessibilityLabel(Text("前の月"))
                    Spacer()
                    Text(monthTitle)
                        .font(KoyomiTheme.headlineFont)
                    Spacer()
                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .frame(width: KoyomiTheme.minimumTapTarget, height: KoyomiTheme.minimumTapTarget)
                    }
                    .accessibilityLabel(Text("次の月"))
                }
                LazyVGrid(columns: Array(repeating: GridItem(), count: 7), spacing: KoyomiTheme.Spacing.s) {
                    ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { symbol in
                        Text(symbol).font(KoyomiTheme.captionFont)
                    }
                    ForEach(monthCells, id: \.id) { cell in
                        dayCell(cell)
                    }
                }
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private struct DayCell: Identifiable {
        let id: String
        let day: Int?
        let dayKey: String?
    }

    private var monthCells: [DayCell] {
        guard let start = calendar.date(from: calendar.dateComponents([.year, .month], from: month)),
              let range = calendar.range(of: .day, in: .month, for: start) else { return [] }
        let leading = calendar.component(.weekday, from: start) - 1
        var cells = (0..<leading).map { DayCell(id: "blank-\($0)", day: nil, dayKey: nil) }
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: start) else { continue }
            let key = KoyomiCalendar.dayKey(for: date, calendar: calendar)
            cells.append(DayCell(id: key, day: day, dayKey: key))
        }
        return cells
    }

    private func dayCell(_ cell: DayCell) -> some View {
        let record = cell.dayKey.flatMap { records[$0] }
        let mood = cell.dayKey.flatMap { moodRecords[$0]?.mood }
        let charm = cell.dayKey.flatMap { ritualRecords[$0] }.flatMap { $0.hasCharm ? $0.charmEmoji : nil }
        return Button {
            if record != nil { selectedDayKey = cell.dayKey }
        } label: {
            VStack(spacing: 2) {
                Text(cell.day.map(String.init) ?? "")
                    .font(KoyomiTheme.bodyFont)
                // 色だけでなく記号で状態を表す。
                Text(charm ?? mood?.emoji ?? (record == nil ? " " : (record?.isFavorite == true ? "♥" : "•")))
                    .font(.caption2)
            }
            .frame(minWidth: KoyomiTheme.minimumTapTarget, minHeight: KoyomiTheme.minimumTapTarget)
        }
        .buttonStyle(.plain)
        .disabled(record == nil)
        .accessibilityLabel(Text(accessibilityLabel(for: cell, record: record, mood: mood)))
    }

    private func accessibilityLabel(for cell: DayCell, record: FortuneRecord?, mood: DailyMood?) -> String {
        guard let day = cell.day else { return "" }
        if record == nil { return "\(day)日 記録なし" }
        let state = record?.isFavorite == true ? "お気に入り" : "記録あり"
        return mood.map { "\(day)日 \(state)、気分は\($0.japaneseName)" } ?? "\(day)日 \(state)"
    }

    private var listCard: some View {
        let items = showFavoritesOnly
            ? records.values.filter(\.isFavorite)
            : Array(records.values)
        return VStack(spacing: KoyomiTheme.Spacing.s) {
            ForEach(items.sorted { $0.dayKey > $1.dayKey }, id: \.dayKey) { record in
                Button {
                    selectedDayKey = record.dayKey
                } label: {
                    GlassCard {
                        VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                            HStack {
                                Text(record.dayKey)
                                    .font(KoyomiTheme.captionFont)
                                Spacer()
                                if record.isFavorite {
                                    Image(systemName: "heart.fill")
                                }
                            }
                            Text(record.fortune?.headline ?? "")
                                .font(KoyomiTheme.bodyFont.weight(.semibold))
                            if let mood = moodRecords[record.dayKey]?.mood {
                                Text("\(mood.emoji) \(mood.japaneseName)")
                                    .font(KoyomiTheme.captionFont)
                            }
                            if let ritual = ritualRecords[record.dayKey], ritual.hasCharm {
                                Text("\(ritual.charmEmoji) \(ritual.charmName)")
                                    .font(KoyomiTheme.captionFont.weight(.semibold))
                            }
                            if let weather = record.weather {
                                Text("\(record.cityName)・\(weather.category.japaneseName) \(weather.temperatureText)")
                                    .font(KoyomiTheme.captionFont)
                                AppleWeatherAttributionView()
                            }
                        }
                        .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var monthTitle: String {
        let components = calendar.dateComponents([.year, .month], from: month)
        return "\(components.year ?? 0)年\(components.month ?? 1)月"
    }

    private func shiftMonth(_ value: Int) {
        if let shifted = calendar.date(byAdding: .month, value: value, to: month) {
            month = shifted
        }
    }

    private func reload() {
        records = Dictionary(uniqueKeysWithValues: environment.store.allRecords().map { ($0.dayKey, $0) })
        moodRecords = Dictionary(uniqueKeysWithValues: environment.store.allMoodRecords().map { ($0.dayKey, $0) })
        ritualRecords = Dictionary(uniqueKeysWithValues: environment.store.allRitualRecords().map { ($0.dayKey, $0) })
        streak = environment.store.currentStreak(today: environment.clock.now, calendar: calendar)
    }

    private var charmCollectionCard: some View {
        let charms = ritualRecords.values.filter(\.hasCharm).sorted { $0.dayKey > $1.dayKey }
        return GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                HStack {
                    Label("つづけた日のしるし", systemImage: "sparkles")
                        .font(KoyomiTheme.headlineFont)
                    Spacer()
                    Text("\(charms.count)個")
                        .font(KoyomiTheme.captionFont.weight(.bold))
                }
                if charms.isEmpty {
                    Text("今日の小さなセルフケアをひとつ終えると、ここにしるしが増えます。")
                        .font(KoyomiTheme.captionFont)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: KoyomiTheme.Spacing.s) {
                            ForEach(charms.prefix(14), id: \.dayKey) { charm in
                                VStack(spacing: 2) {
                                    Text(charm.charmEmoji).font(.title)
                                    Text(charm.dayKey.suffix(5))
                                        .font(.system(size: 9))
                                }
                                .frame(width: 52, height: 58)
                                .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: KoyomiTheme.Radius.small))
                                .accessibilityLabel("\(charm.dayKey)、\(charm.charmName)")
                            }
                        }
                    }
                }
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var streakMessage: String {
        switch streak {
        case 1: return "今日のあなたに会えてうれしいです。"
        case 2...6: return "小さな習慣が、少しずつ育っています。"
        case 7...29: return "一週間以上の記録。あなたらしいリズムです。"
        default: return "積み重ねた日々が、あなただけの暦になりました。"
        }
    }
}

/// 過去の日の詳細。保存時の天気要約と占いをそのまま表示する。
struct HistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let record: FortuneRecord
    let fortune: DailyFortune
    let moodRecord: DailyMoodRecord?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                    if let weather = record.weather {
                        Text("\(record.cityName)・\(weather.category.japaneseName) \(weather.temperatureText)")
                            .font(KoyomiTheme.captionFont)
                        AppleWeatherAttributionView()
                    } else {
                        Text("この日はお天気情報がありませんでした。")
                            .font(KoyomiTheme.captionFont)
                    }
                    Text(fortune.headline)
                        .font(KoyomiTheme.headlineFont)
                    if let mood = moodRecord?.mood {
                        Label("この日の気分：\(mood.emoji) \(mood.japaneseName)", systemImage: "heart.text.square")
                            .font(KoyomiTheme.bodyFont.weight(.semibold))
                    }
                    ScoreStars(score: fortune.overallScore, size: 18)
                    Text(fortune.overall)
                    Text(fortune.skySign)
                    Text("今日の小さなアクション：\(fortune.action)")
                    if let reflection = moodRecord?.reflectionText, !reflection.isEmpty {
                        VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                            Text("夜のひとこと")
                                .font(KoyomiTheme.captionFont)
                                .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
                            Text(reflection)
                        }
                        .padding(KoyomiTheme.Spacing.m)
                        .background(KoyomiTheme.cardFill(colorScheme), in: RoundedRectangle(cornerRadius: KoyomiTheme.Radius.small))
                    }
                    Text(fortune.disclaimer)
                        .font(KoyomiTheme.captionFont)
                }
                .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
                .padding(KoyomiTheme.Spacing.m)
            }
            .navigationTitle(record.dayKey)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
