import SwiftUI
import KoyomiCore

/// 端末内の記録だけで、気分・セルフケア・空模様の傾向を振り返る画面。
struct RhythmInsightsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let environment: AppEnvironment

    @State private var moods: [DailyMoodRecord] = []
    @State private var rituals: [DailyRitualRecord] = []
    @State private var fortunes: [FortuneRecord] = []

    private var recent7: [DailyMoodRecord] { Array(moods.prefix(7)) }
    private var recent30: [DailyMoodRecord] { Array(moods.prefix(30)) }

    var body: some View {
        ZStack {
            NightSkyBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                    introduction
                    summaryCard
                    weeklyRhythmCard
                    moodBalanceCard
                    weatherMoodCard
                    privacyCard
                }
                .padding(KoyomiTheme.Spacing.m)
            }
        }
        .onAppear(perform: reload)
        .accessibilityIdentifier("rhythm.insights")
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
            Text("わたしのリズム")
                .font(KoyomiTheme.titleFont)
            Text("気分と小さな行動を重ねて、自分に合う過ごし方を見つけよう。")
                .font(KoyomiTheme.bodyFont)
        }
        .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
    }

    private var summaryCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                Text("この30日の記録")
                    .font(KoyomiTheme.headlineFont)
                HStack(spacing: KoyomiTheme.Spacing.s) {
                    metric(value: "\(recent30.compactMap(\.mood).count)", label: "気分")
                    metric(value: "\(completedTaskCount)", label: "小さな行動")
                    metric(value: "\(reflectionCount)", label: "夜メモ")
                }
                Text(personalInsight)
                    .font(KoyomiTheme.bodyFont.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private func metric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold())
            Text(label).font(KoyomiTheme.captionFont)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KoyomiTheme.Spacing.s)
        .background(Color.white.opacity(0.18), in: RoundedRectangle(cornerRadius: KoyomiTheme.Radius.small))
    }

    private var weeklyRhythmCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                Text("最近7回の気分")
                    .font(KoyomiTheme.headlineFont)
                if recent7.compactMap(\.mood).isEmpty {
                    Text("今日の気分を残すと、ここにあなたのリズムが育ちます。")
                        .font(KoyomiTheme.bodyFont)
                } else {
                    HStack(alignment: .bottom, spacing: KoyomiTheme.Spacing.s) {
                        ForEach(recent7.reversed(), id: \.dayKey) { record in
                            VStack(spacing: 4) {
                                Text(record.mood?.emoji ?? "・").font(.title2)
                                Capsule()
                                    .fill(KoyomiTheme.strawberryMilk.opacity(0.75))
                                    .frame(height: moodHeight(record.mood))
                                Text(String(record.dayKey.suffix(2)))
                                    .font(.caption2)
                            }
                            .frame(maxWidth: .infinity)
                            .accessibilityLabel("\(record.dayKey)、\(record.mood?.japaneseName ?? "未記録")")
                        }
                    }
                    .frame(height: 118, alignment: .bottom)
                }
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var moodBalanceCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                Text("気分のバランス")
                    .font(KoyomiTheme.headlineFont)
                ForEach(DailyMood.allCases) { mood in
                    let count = recent30.filter { $0.mood == mood }.count
                    HStack {
                        Text("\(mood.emoji) \(mood.japaneseName)")
                            .font(KoyomiTheme.bodyFont)
                        Spacer()
                        ProgressView(value: Double(count), total: Double(max(1, recent30.count)))
                            .tint(KoyomiTheme.strawberryMilk)
                            .frame(width: 100)
                        Text("\(count)日")
                            .font(KoyomiTheme.captionFont.monospacedDigit())
                            .frame(width: 34, alignment: .trailing)
                    }
                }
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var weatherMoodCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                Label("空模様と気分", systemImage: "cloud.sun")
                    .font(KoyomiTheme.headlineFont)
                if weatherMoodPairs.isEmpty {
                    Text("天気と気分の記録が増えると、組み合わせを振り返れます。")
                        .font(KoyomiTheme.bodyFont)
                } else {
                    ForEach(weatherMoodPairs.prefix(4), id: \.key) { pair in
                        HStack {
                            Text(pair.key)
                            Spacer()
                            Text("\(pair.value)回").monospacedDigit()
                        }
                        .font(KoyomiTheme.bodyFont)
                    }
                    AppleWeatherAttributionView()
                }
                Text("気分は天気だけで決まるものではありません。診断ではなく、あなた自身の振り返りのための表示です。")
                    .font(KoyomiTheme.captionFont)
                    .foregroundStyle(KoyomiTheme.secondaryText(colorScheme))
            }
            .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var privacyCard: some View {
        GlassCard {
            Label("分析はすべて端末内。気分やメモを外部へ送信しません。", systemImage: "lock.shield")
                .font(KoyomiTheme.captionFont)
                .foregroundStyle(KoyomiTheme.primaryText(colorScheme))
        }
    }

    private var completedTaskCount: Int {
        rituals.prefix(30).reduce(0) { $0 + $1.completedTaskIDs.count }
    }

    private var reflectionCount: Int {
        recent30.filter { !$0.reflectionText.isEmpty }.count
    }

    private var personalInsight: String {
        let values = recent30.compactMap(\.mood)
        guard !values.isEmpty else { return "最初のチェックインから、あなた専用の振り返りが始まります。" }
        let grouped = Dictionary(grouping: values, by: { $0 }).mapValues(\.count)
        guard let mood = grouped.max(by: { $0.value < $1.value })?.key else { return "少しずつ、あなたらしいリズムが見えてきます。" }
        switch mood {
        case .energized: return "元気な日が多め。動けた日の小さな習慣を、疲れた日の味方にもしてみて。"
        case .calm: return "穏やかな日が多め。心地よかった時間帯や場所も夜メモに残してみて。"
        case .fluttering: return "ときめきを感じた日が多め。好きなものとの出会いを大切にできています。"
        case .tired: return "おつかれの日が多め。達成数より休めたことを大切な記録として数えてみて。"
        case .cloudy: return "もやもやの日が多め。短い言葉でも残すと、変化のきっかけを見つけやすくなります。"
        }
    }

    private var weatherMoodPairs: [(key: String, value: Int)] {
        let moodByDay = Dictionary(uniqueKeysWithValues: moods.compactMap { record in
            record.mood.map { (record.dayKey, $0) }
        })
        var counts: [String: Int] = [:]
        for record in fortunes.prefix(30) {
            guard let weather = record.weather, let mood = moodByDay[record.dayKey] else { continue }
            counts["\(weather.category.japaneseName) × \(mood.emoji) \(mood.japaneseName)", default: 0] += 1
        }
        return counts.sorted { lhs, rhs in
            lhs.value == rhs.value ? lhs.key < rhs.key : lhs.value > rhs.value
        }
    }

    private func moodHeight(_ mood: DailyMood?) -> CGFloat {
        switch mood {
        case .energized: 66
        case .calm: 54
        case .fluttering: 60
        case .tired: 32
        case .cloudy: 40
        case nil: 12
        }
    }

    private func reload() {
        moods = environment.store.allMoodRecords()
        rituals = environment.store.allRitualRecords()
        fortunes = environment.store.allRecords()
    }
}
