import SwiftUI

struct ContentView: View {
    @StateObject private var store = AppStore()
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView()
                    .transition(.opacity)
            } else if !store.hasCompletedOnboarding {
                OnboardingView(store: store)
                    .transition(.opacity)
            } else {
                MainTabView(store: store)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.45), value: showSplash)
        .animation(.easeInOut(duration: 0.45), value: store.hasCompletedOnboarding)
        .task {
            store.resetDailyUsageIfNeeded()
            try? await Task.sleep(for: .seconds(2))
            showSplash = false
        }
    }
}

private struct SplashView: View {
    @State private var moonVisible = false

    var body: some View {
        ZStack {
            MoonlitBackground()
            VStack(spacing: 24) {
                Image(systemName: "moon.stars.fill")
                    .font(.system(size: 92))
                    .foregroundStyle(AppTheme.gold)
                    .shadow(color: AppTheme.gold.opacity(0.45), radius: 10)
                    .scaleEffect(moonVisible ? 1 : 0.72)
                    .opacity(moonVisible ? 1 : 0)
                Text("月が、あなたの運命を照らします")
                    .font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
            }
            .padding(28)
        }
        .onAppear { moonVisible = true }
    }
}

private struct OnboardingView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("月詠み AI占い")
                            .font(.system(.largeTitle, design: .serif).weight(.bold))
                            .foregroundStyle(.white)
                        Text("あなた専用の星を読み解くために、少しだけ教えてください。")
                            .font(.body)
                            .foregroundStyle(AppTheme.softWhite)
                    }
                    .padding(.top, 28)

                    GlassPanel {
                        VStack(spacing: 16) {
                            TextField("ニックネーム", text: $store.profile.nickname)
                                .textFieldStyle(.roundedBorder)
                            DatePicker("生年月日", selection: $store.profile.birthday, displayedComponents: .date)
                                .foregroundStyle(.white)
                            Picker("性別", selection: $store.profile.gender) {
                                ForEach(["女性", "男性", "その他", "未設定"], id: \.self) { Text($0) }
                            }
                            .pickerStyle(.segmented)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("恋愛状況")
                                .sectionTitle()
                            Picker("恋愛状況", selection: $store.profile.loveStatus) {
                                ForEach(LoveStatus.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.inline)
                        }
                    }

                    GlassPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("気になるジャンル")
                                .sectionTitle()
                            ForEach(Interest.allCases) { interest in
                                Toggle(interest.rawValue, isOn: Binding(
                                    get: { store.profile.interests.contains(interest) },
                                    set: { isOn in
                                        if isOn {
                                            store.profile.interests.insert(interest)
                                        } else {
                                            store.profile.interests.remove(interest)
                                        }
                                    }
                                ))
                                .tint(AppTheme.gold)
                                .foregroundStyle(.white)
                            }
                        }
                    }

                    Button {
                        store.completeOnboarding()
                    } label: {
                        Text("月のメッセージを受け取る")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(GlowButtonStyle())
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 20)
            }
            .background(MoonlitBackground())
        }
    }
}

private struct MainTabView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem { Label("ホーム", systemImage: "moon.stars.fill") }
            DailyFortuneView(store: store)
                .tabItem { Label("今日", systemImage: "sparkles") }
            LoveFortuneView(store: store)
                .tabItem { Label("恋愛", systemImage: "heart.fill") }
            ChatFortuneView(store: store)
                .tabItem { Label("相談", systemImage: "bubble.left.and.bubble.right.fill") }
            CalendarView(store: store)
                .tabItem { Label("暦", systemImage: "calendar") }
            MyPageView(store: store)
                .tabItem { Label("マイページ", systemImage: "person.crop.circle.fill") }
        }
        .tint(AppTheme.gold)
    }
}

private struct HomeView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    HeroHeader(profile: store.profile, today: store.today)
                    HomeFeatureGrid(store: store)
                    MoonMessageCard()
                    OmikujiCard(store: store)
                    PremiumTeaser(store: store)
                    HistoryPreview(history: store.history)
                    if store.shouldShowAds { AdBannerView() }
                    LegalNoticeCard()
                }
                .padding()
            }
            .background(MoonlitBackground())
            .navigationTitle("月詠み AI占い")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct HeroHeader: View {
    let profile: UserProfile
    let today: FortuneResult

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("こんばんは、\(profile.nickname)さん")
                            .font(.system(.title2, design: .serif).weight(.bold))
                            .foregroundStyle(.white)
                        Text("今夜の月は、あなたに小さな変化を知らせています。")
                            .foregroundStyle(AppTheme.softWhite)
                    }
                    Spacer()
                    Image(systemName: "moon.fill")
                        .font(.system(size: 42))
                        .foregroundStyle(AppTheme.gold)
                        .shadow(color: AppTheme.gold.opacity(0.35), radius: 8)
                }
                ScoreRing(title: "今日の月詠み", score: today.overall, size: 124)
                    .frame(maxWidth: .infinity)
                Text("今日のあなたは、少しだけ心が揺れやすい日。でも大丈夫。月はちゃんと、あなたの味方です。")
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct HomeFeatureGrid: View {
    @ObservedObject var store: AppStore

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            NavigationLink { DailyFortuneView(store: store) } label: {
                FeatureTile(title: "今日の運勢", icon: "sparkles", text: "月の流れから今夜の運勢を読む")
            }
            NavigationLink { LoveFortuneView(store: store) } label: {
                FeatureTile(title: "恋愛占い", icon: "heart.text.square.fill", text: "彼の心の奥をそっと読み解く")
            }
            NavigationLink { PartnerFeelingView(store: store) } label: {
                FeatureTile(title: "相手の気持ち", icon: "person.line.dotted.person.fill", text: "言葉にならない想いを診断")
            }
            NavigationLink { ChatFortuneView(store: store) } label: {
                FeatureTile(title: "AIチャット占い", icon: "bubble.left.and.text.bubble.right.fill", text: "LINE風に悩みを相談")
            }
            NavigationLink { OmikujiView(store: store) } label: {
                FeatureTile(title: "おみくじ", icon: "scroll.fill", text: "今日一度の恋みくじ")
            }
            NavigationLink { CalendarView(store: store) } label: {
                FeatureTile(title: "開運カレンダー", icon: "calendar.badge.clock", text: "月と星の流れを確認")
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FeatureTile: View {
    let title: String
    let icon: String
    let text: String

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(AppTheme.gold)
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(text)
                    .font(.caption)
                    .foregroundStyle(AppTheme.softWhite)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct MoonMessageCard: View {
    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("月からのメッセージ")
                    .sectionTitle()
                Text("私のことを分かってくれる。少し安心した。また明日も見たい。そんな夜に寄り添う占いを届けます。")
                    .foregroundStyle(AppTheme.softWhite)
            }
        }
    }
}

private struct DailyFortuneView: View {
    @ObservedObject var store: AppStore
    @State private var phaseIndex = 0
    @State private var showSaved = false
    private let phases = ["星を読み取っています…", "月の流れを確認しています…", "あなたへのメッセージを受信しました"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassPanel {
                        VStack(spacing: 14) {
                            Text(phases[phaseIndex])
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.lavender)
                            Text("今日の運勢")
                                .font(.system(.largeTitle, design: .serif).weight(.bold))
                                .foregroundStyle(.white)
                            Text(store.today.date.formatted(date: .long, time: .omitted))
                                .foregroundStyle(AppTheme.softWhite)
                            ScoreRing(title: "総合運", score: store.today.overall, size: 150)
                        }
                    }

                    LuckScores(result: store.today)
                    LuckyDetails(result: store.today, isPremium: store.isPremium)

                    HStack {
                        Button {
                            store.saveTodayFortune()
                            showSaved = true
                        } label: {
                            Label("保存", systemImage: "tray.and.arrow.down.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlowButtonStyle())

                        ShareLink(item: shareText) {
                            Label("共有", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.gold)
                    }

                    if store.shouldShowAds { AdBannerView() }
                }
                .padding()
            }
            .background(MoonlitBackground())
            .navigationTitle("今日の運勢")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .alert("占い履歴に保存しました", isPresented: $showSaved) {
                Button("OK", role: .cancel) {}
            }
            .task {
                for index in phases.indices {
                    phaseIndex = index
                    try? await Task.sleep(for: .milliseconds(650))
                }
            }
        }
    }

    private var shareText: String {
        "月詠み AI占い: 今日の総合運は\(store.today.overall)点。ラッキーカラーは\(store.today.luckyColor)。"
    }
}

private struct LuckScores: View {
    let result: FortuneResult

    var body: some View {
        GlassPanel {
            VStack(spacing: 12) {
                MeterRow(title: "恋愛運", value: result.love, color: AppTheme.romancePink)
                MeterRow(title: "仕事運", value: result.work, color: AppTheme.lavender)
                MeterRow(title: "金運", value: result.money, color: AppTheme.gold)
                MeterRow(title: "健康運", value: result.health, color: .mint)
            }
        }
    }
}

private struct LuckyDetails: View {
    let result: FortuneResult
    let isPremium: Bool

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 12) {
                ResultBlock(title: "ラッキーカラー", icon: "paintpalette.fill", text: result.luckyColor)
                ResultBlock(title: "ラッキーアイテム", icon: "sparkle.magnifyingglass", text: result.luckyItem)
                ResultBlock(title: "今日の一言", icon: "moon.stars.fill", text: result.advice)
                Divider().overlay(AppTheme.gold.opacity(0.5))
                ResultBlock(title: "月詠み詳細", icon: "doc.text.magnifyingglass", text: isPremium ? result.detail : "ここから先は、あなたと彼の流れをさらに深く読み解きます。")
            }
        }
    }
}

private struct LoveFortuneView: View {
    @ObservedObject var store: AppStore
    @State private var question: LoveQuestion = .feeling
    @State private var result: CompatibilityResult?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    GlassPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("彼の心の奥にある、まだ言葉になっていない想いを読み解きます。")
                                .foregroundStyle(.white)
                            Picker("占いたいこと", selection: $question) {
                                ForEach(LoveQuestion.allCases) { Text($0.rawValue).tag($0) }
                            }
                            .pickerStyle(.inline)
                            Button {
                                result = FortuneEngine.compatibility(
                                    userBirthday: store.profile.birthday,
                                    partnerBirthday: .now,
                                    relationship: .crush,
                                    concern: question.rawValue + store.profile.loveStatus.rawValue
                                )
                            } label: {
                                Text("恋の流れを読む")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(GlowButtonStyle())
                        }
                    }

                    if let result {
                        CompatibilityResultView(result: result, isPremium: store.isPremium)
                    }

                    NavigationLink {
                        PartnerFeelingView(store: store)
                    } label: {
                        FeatureTile(title: "相手の気持ち診断へ", icon: "heart.circle.fill", text: "相手の名前や最近の状況から、もう少し具体的に読む")
                    }
                    .buttonStyle(.plain)

                    if store.shouldShowAds { AdBannerView() }
                }
                .padding()
            }
            .background(MoonlitBackground())
            .navigationTitle("恋愛占い")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct PartnerFeelingView: View {
    @ObservedObject var store: AppStore
    @State private var partnerName = ""
    @State private var partnerBirthday = Date.now
    @State private var knowsBirthday = false
    @State private var relationship: Relationship = .crush
    @State private var situation = "最近、返信が少し遅いです"
    @State private var result: CompatibilityResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("相手の気持ち診断")
                            .font(.system(.title2, design: .serif).weight(.bold))
                            .foregroundStyle(.white)
                        TextField("相手の名前 任意", text: $partnerName)
                            .textFieldStyle(.roundedBorder)
                        Toggle("相手の誕生日が分かる", isOn: $knowsBirthday)
                            .tint(AppTheme.gold)
                            .foregroundStyle(.white)
                        if knowsBirthday {
                            DatePicker("相手の誕生日", selection: $partnerBirthday, displayedComponents: .date)
                                .foregroundStyle(.white)
                        }
                        Picker("関係性", selection: $relationship) {
                            ForEach(Relationship.allCases) { Text($0.rawValue).tag($0) }
                        }
                        TextField("最近の状況", text: $situation, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(2...5)
                        Button {
                            result = FortuneEngine.compatibility(
                                userBirthday: store.profile.birthday,
                                partnerBirthday: knowsBirthday ? partnerBirthday : .now,
                                relationship: relationship,
                                concern: partnerName + situation
                            )
                        } label: {
                            Text("彼の本音を読む")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(GlowButtonStyle())
                    }
                }

                if let result {
                    CompatibilityResultView(result: result, isPremium: store.isPremium)
                }
            }
            .padding()
        }
        .background(MoonlitBackground())
        .navigationTitle("相手の気持ち")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct CompatibilityResultView: View {
    let result: CompatibilityResult
    let isPremium: Bool

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                ScoreRing(title: "恋の月齢", score: result.score, size: 132)
                    .frame(maxWidth: .infinity)
                ResultBlock(title: "今の彼の気持ち", icon: "heart.fill", text: result.feeling)
                ResultBlock(title: "あなたへの印象", icon: "sparkles", text: "あなたのやさしさや空気感は、相手の中に静かに残っています。今は強く迫るより、安心できる存在でいることが鍵です。")
                ResultBlock(title: "近いうちに起こりそうなこと", icon: "arrow.triangle.branch", text: result.flow)
                ResultBlock(title: "今してはいけない行動", icon: "exclamationmark.triangle.fill", text: result.avoidAction)
                ResultBlock(title: "開運アドバイス", icon: "moon.stars.fill", text: isPremium ? result.advice : "ここから先は、あなたと彼の流れをさらに深く読み解きます。")
            }
        }
    }
}

private struct ChatFortuneView: View {
    @ObservedObject var store: AppStore
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.chatMessages) { ChatBubble(message: $0) }
                    }
                    .padding()
                }
                Divider().overlay(AppTheme.gold.opacity(0.5))
                HStack(alignment: .bottom, spacing: 10) {
                    TextField("彼から返信が遅いです", text: $draft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    Button {
                        store.sendConsultation(draft)
                        draft = ""
                    } label: {
                        Image(systemName: "paperplane.fill")
                    }
                    .buttonStyle(GlowIconButtonStyle())
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.remainingConsultations <= 0)
                }
                .padding()
                .background(AppTheme.midnight.opacity(0.92))
            }
            .background(MoonlitBackground())
            .navigationTitle("AIチャット占い")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                Text(store.isPremium ? "無制限" : "残り\(store.remainingConsultations)回")
                    .font(.caption)
                    .foregroundStyle(AppTheme.gold)
            }
        }
    }
}

private struct OmikujiView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                OmikujiCard(store: store)
                Text("無料プランでは、おみくじは1日1回を想定しています。")
                    .font(.footnote)
                    .foregroundStyle(AppTheme.softWhite)
            }
            .padding()
        }
        .background(MoonlitBackground())
        .navigationTitle("おみくじ")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct OmikujiCard: View {
    @ObservedObject var store: AppStore

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("恋みくじ", systemImage: "scroll.fill")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Button(store.dailyOmikujiResult == nil || store.isPremium ? "引く" : "本日済み") {
                        store.drawOmikuji()
                    }
                    .disabled(!store.isPremium && store.dailyOmikujiResult != nil)
                        .buttonStyle(.bordered)
                        .tint(AppTheme.gold)
                }
                if let result = store.dailyOmikujiResult {
                    Text(result.rank)
                        .font(.system(.largeTitle, design: .serif).weight(.bold))
                        .foregroundStyle(AppTheme.gold)
                    Text(result.message)
                        .foregroundStyle(.white)
                    Text("お守り: \(result.charm)")
                        .font(.caption)
                        .foregroundStyle(AppTheme.softWhite)
                } else {
                    Text("今日のおみくじを引いて、短い開運メッセージを確認できます。")
                        .foregroundStyle(AppTheme.softWhite)
                }
                if !store.isPremium {
                    Text("無料プランでは1日1回まで。Premiumでは何度でも引けます。")
                        .font(.caption)
                        .foregroundStyle(AppTheme.softWhite)
                }
            }
        }
    }
}

private struct CalendarView: View {
    @ObservedObject var store: AppStore
    private let days = (0..<30).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: .now) }

    var body: some View {
        NavigationStack {
            List {
                Toggle("毎朝の通知", isOn: $store.notificationsEnabled)
                    .tint(AppTheme.gold)
                ForEach(days, id: \.self) { date in
                    HStack(spacing: 12) {
                        Image(systemName: Calendar.current.component(.day, from: date).isMultiple(of: 2) ? "moonphase.new.moon" : "moonphase.full.moon")
                            .foregroundStyle(AppTheme.gold)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.headline)
                            Text(calendarAdvice(for: date))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MoonlitBackground())
            .navigationTitle("開運カレンダー")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }

    private func calendarAdvice(for date: Date) -> String {
        let values = ["連絡運が上がる日", "整理整頓で金運アップ", "新しい予定を入れる日", "休息を優先する日", "自分磨きに向く日", "推し活が楽しめる日", "金運メモをつける日"]
        return values[Calendar.current.component(.day, from: date) % values.count]
    }
}

private struct MyPageView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NavigationStack {
            Form {
                Section("基本プロフィール") {
                    TextField("ニックネーム", text: $store.profile.nickname)
                    DatePicker("生年月日", selection: $store.profile.birthday, displayedComponents: .date)
                    Picker("恋愛状況", selection: $store.profile.loveStatus) {
                        ForEach(LoveStatus.allCases) { Text($0.rawValue).tag($0) }
                    }
                    Picker("血液型", selection: $store.profile.bloodType) {
                        ForEach(["A", "B", "O", "AB", "未設定"], id: \.self) { Text($0) }
                    }
                    Picker("性別", selection: $store.profile.gender) {
                        ForEach(["女性", "男性", "その他", "未設定"], id: \.self) { Text($0) }
                    }
                }

                Section("気になるジャンル") {
                    ForEach(Interest.allCases) { interest in
                        Toggle(interest.rawValue, isOn: Binding(
                            get: { store.profile.interests.contains(interest) },
                            set: { isOn in
                                if isOn {
                                    store.profile.interests.insert(interest)
                                } else {
                                    store.profile.interests.remove(interest)
                                }
                            }
                        ))
                    }
                }

                Section("占い") {
                    NavigationLink("生年月日占い") { BirthFortuneView(store: store) }
                    NavigationLink("週間・月間運勢") { PeriodFortuneView(store: store) }
                    NavigationLink("占い履歴 \(store.history.count)件") { HistoryView(history: store.history) }
                }

                Section("設定") {
                    NavigationLink("設定") { SettingsView(store: store) }
                    NavigationLink("プレミアム") { PremiumView(store: store) }
                }

                Section("法務・審査対応") {
                    NavigationLink("Legal") { LegalView() }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MoonlitBackground())
            .navigationTitle("マイページ")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

private struct BirthFortuneView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List(FortuneEngine.birthFortunes(for: store.profile)) { item in
            VStack(alignment: .leading, spacing: 8) {
                Text(item.title)
                    .font(.headline)
                Text(item.summary)
                Text(item.advice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        }
        .scrollContentBackground(.hidden)
        .background(MoonlitBackground())
        .navigationTitle("生年月日占い")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct PeriodFortuneView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List {
            ResultBlock(title: "週間運勢", icon: "calendar", text: FortuneEngine.periodFortune(title: "今週", profile: store.profile, days: 7))
            ResultBlock(title: "月間運勢", icon: "calendar.circle.fill", text: FortuneEngine.periodFortune(title: "今月", profile: store.profile, days: 30))
            ResultBlock(title: "満月・新月占い", icon: "moonphase.full.moon", text: "満ちる時期は振り返り、新しい月の時期は小さな目標設定に向いています。恋に迷う夜は、答えを急がず自分の心を整えてください。")
        }
        .scrollContentBackground(.hidden)
        .background(MoonlitBackground())
        .navigationTitle("週間・月間運勢")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct PremiumView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("もっと深く、運命を読み解く")
                        .font(.system(.title2, design: .serif).weight(.bold))
                    Text("AI相談無制限、詳細恋愛占い、相手の本音診断、復縁占い、結婚時期占い、広告非表示、履歴保存を開放します。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Section("プラン") {
                ForEach(PremiumPlan.all) { plan in
                    Button {
                        store.selectedPlanID = plan.id
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(plan.title).font(.headline)
                                Text(plan.price).foregroundStyle(AppTheme.gold)
                                Text(plan.description).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selectedPlanID == plan.id {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppTheme.gold)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Section {
                Button("もっと深く、運命を読み解く") { store.purchaseSelectedPlan() }
                Button("購入を復元") { store.restorePurchase() }
                if store.isPremium {
                    Button("テスト用に無料へ戻す", role: .destructive) { store.cancelPremiumForTesting() }
                }
            } footer: {
                Text("この画面はStoreKit連携前のローカル実装です。リリース時はAppleの自動更新サブスクリプション、解約条件、価格、返金ポリシーを正確に表示してください。")
            }
        }
        .scrollContentBackground(.hidden)
        .background(MoonlitBackground())
        .navigationTitle("Premium")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct SettingsView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Form {
            Toggle("毎朝の通知", isOn: $store.notificationsEnabled)
            Toggle("プレミアム状態", isOn: $store.isPremium)
            Button("初回登録をもう一度表示") { store.resetOnboardingForTesting() }
        }
        .scrollContentBackground(.hidden)
        .background(MoonlitBackground())
        .navigationTitle("設定")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct HistoryView: View {
    let history: [FortuneResult]

    var body: some View {
        List(history) { item in
            NavigationLink {
                FortuneHistoryDetailView(item: item)
            } label: {
                VStack(alignment: .leading) {
                    Text(item.date.formatted(date: .long, time: .omitted))
                    Text("総合 \(item.overall) / 恋愛 \(item.love) / 仕事 \(item.work)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(MoonlitBackground())
        .navigationTitle("占い履歴")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct FortuneHistoryDetailView: View {
    let item: FortuneResult

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ScoreRing(title: "総合運", score: item.overall, size: 132)
                LuckScores(result: item)
                LuckyDetails(result: item, isPremium: true)
            }
            .padding()
        }
        .background(MoonlitBackground())
        .navigationTitle("履歴詳細")
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct LegalView: View {
    var body: some View {
        List {
            NavigationLink("利用規約") { LegalTextView(title: "利用規約", text: LegalTexts.terms) }
            NavigationLink("プライバシーポリシー") { LegalTextView(title: "プライバシーポリシー", text: LegalTexts.privacy) }
            NavigationLink("特定商取引法に基づく表記") { LegalTextView(title: "特定商取引法に基づく表記", text: LegalTexts.commercial) }
            NavigationLink("サブスクリプション説明") { LegalTextView(title: "サブスクリプション説明", text: LegalTexts.subscription) }
            NavigationLink("App Store説明文") { LegalTextView(title: "App Store説明文", text: LegalTexts.appStoreDescription) }
            NavigationLink("免責事項") { LegalTextView(title: "免責事項", text: LegalTexts.disclaimer) }
        }
        .navigationTitle("Legal")
    }
}

private struct LegalTextView: View {
    let title: String
    let text: String

    var body: some View {
        ScrollView {
            Text(text)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .background(MoonlitBackground())
        .navigationTitle(title)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct PremiumTeaser: View {
    @ObservedObject var store: AppStore

    var body: some View {
        NavigationLink {
            PremiumView(store: store)
        } label: {
            GlassPanel {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(store.isPremium ? "Premium 有効" : "Premium", systemImage: "crown.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(store.isPremium ? "広告非表示" : "¥480/月から")
                            .font(.subheadline.bold())
                            .foregroundStyle(AppTheme.gold)
                    }
                    Text("ここから先は、あなたと彼の流れをさらに深く読み解きます。")
                        .foregroundStyle(AppTheme.softWhite)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryPreview: View {
    let history: [FortuneResult]

    var body: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 10) {
                Label("占い履歴", systemImage: "clock.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                if history.isEmpty {
                    Text("今日の運勢を保存すると、ここに履歴が表示されます。")
                        .foregroundStyle(AppTheme.softWhite)
                } else {
                    ForEach(history.prefix(3)) { item in
                        HStack {
                            Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text("総合 \(item.overall)")
                        }
                        .foregroundStyle(AppTheme.softWhite)
                    }
                }
            }
        }
    }
}

private struct LegalNoticeCard: View {
    var body: some View {
        GlassPanel {
            Text(LegalTexts.disclaimer)
                .font(.footnote)
                .foregroundStyle(AppTheme.softWhite)
        }
    }
}

private struct AdBannerView: View {
    var body: some View {
        HStack {
            Image(systemName: "rectangle.and.text.magnifyingglass")
            Text("広告表示エリア")
            Spacer()
            Text("無料プラン")
                .font(.caption)
        }
        .foregroundStyle(AppTheme.softWhite)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.gold.opacity(0.35), lineWidth: 1))
    }
}

private struct ResultBlock: View {
    let title: String
    let icon: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(.white)
            Text(text)
                .foregroundStyle(AppTheme.softWhite)
        }
    }
}

private struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.sender == .app {
                bubble
                Spacer(minLength: 42)
            } else {
                Spacer(minLength: 42)
                bubble
            }
        }
    }

    private var bubble: some View {
        Text(message.text)
            .foregroundStyle(message.sender == .app ? .white : AppTheme.midnight)
            .padding(12)
            .background(message.sender == .app ? .white.opacity(0.12) : AppTheme.romancePink.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(message.sender == .app ? AppTheme.gold.opacity(0.3) : .clear, lineWidth: 1))
    }
}

private struct ScoreRing: View {
    let title: String
    let score: Int
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(AppTheme.gold.opacity(0.18), lineWidth: 12)
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(AppTheme.gold, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 4) {
                Text(title).font(.caption).foregroundStyle(AppTheme.softWhite)
                Text("\(score)")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(title) \(score)点")
    }
}

private struct MeterRow: View {
    let title: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Text("\(value)")
                    .font(.subheadline.monospacedDigit())
            }
            .foregroundStyle(.white)
            ProgressView(value: Double(value), total: 100)
                .tint(color)
        }
    }
}

private struct GlassPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(AppTheme.gold.opacity(0.42), lineWidth: 1))
            .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
}

private struct MoonlitBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.midnight, AppTheme.mysticPurple, AppTheme.oraclePurple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(AppTheme.gold.opacity(0.11))
                .frame(width: 170, height: 170)
                .offset(x: 110, y: -245)

            ForEach(0..<16, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 3) ? AppTheme.gold.opacity(0.85) : .white.opacity(0.75))
                    .frame(width: CGFloat((index % 3) + 2), height: CGFloat((index % 3) + 2))
                    .offset(x: starX(index), y: starY(index))
            }
        }
    }

    private func starX(_ index: Int) -> CGFloat {
        CGFloat((index * 47) % 360 - 180)
    }

    private func starY(_ index: Int) -> CGFloat {
        CGFloat((index * 83) % 760 - 380)
    }
}

private struct GlowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded))
            .foregroundStyle(AppTheme.midnight)
            .padding(.vertical, 13)
            .background(AppTheme.gold, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.gold.opacity(configuration.isPressed ? 0.20 : 0.38), radius: configuration.isPressed ? 4 : 8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private struct GlowIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.midnight)
            .padding(12)
            .background(AppTheme.gold, in: Circle())
            .shadow(color: AppTheme.gold.opacity(configuration.isPressed ? 0.20 : 0.38), radius: configuration.isPressed ? 4 : 8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
    }
}

private extension Text {
    func sectionTitle() -> some View {
        font(.system(.headline, design: .serif).weight(.semibold))
            .foregroundStyle(AppTheme.gold)
    }
}

private enum AppTheme {
    static let midnight = Color(red: 0.059, green: 0.063, blue: 0.157)
    static let mysticPurple = Color(red: 0.118, green: 0.090, blue: 0.271)
    static let oraclePurple = Color(red: 0.231, green: 0.145, blue: 0.427)
    static let gold = Color(red: 0.847, green: 0.706, blue: 0.353)
    static let romancePink = Color(red: 0.969, green: 0.843, blue: 0.910)
    static let lavender = Color(red: 0.749, green: 0.655, blue: 1.0)
    static let softWhite = Color.white.opacity(0.78)
}

private enum LegalTexts {
    static let terms = """
    本アプリは、占い結果および相談風コンテンツを娯楽・参考情報として提供します。利用者は、結果が将来の出来事、恋愛、仕事、健康、金銭その他の成果を保証するものではないことを理解した上で利用します。

    他者を傷つける行為、法令に反する利用、過度な依存につながる利用はお控えください。
    """

    static let privacy = """
    入力されたニックネーム、生年月日、恋愛状況、興味ジャンル、相談内容は、占い結果の表示およびアプリ体験の改善を目的として取り扱います。

    実際のリリース時には、収集項目、利用目的、第三者提供、広告ID、解析SDK、問い合わせ窓口、削除依頼の方法を明記してください。
    """

    static let commercial = """
    販売事業者、所在地、連絡先、販売価格、支払方法、役務提供時期、解約方法、返金条件をリリース前に正確に記載してください。

    サブスクリプションは自動更新であること、更新日の24時間以上前に解約が必要なことを明確に表示してください。
    """

    static let subscription = """
    月額480円、月額980円、年額4,800円のプランを想定しています。購入後はApple IDに課金され、期間終了の24時間以上前に解約しない限り自動更新されます。

    実リリース時はStoreKitの商品ID、価格、無料トライアル有無、解約方法、更新条件をApp Store Connectの設定と一致させてください。
    """

    static let appStoreDescription = """
    月詠み AI占いは、あなたの毎日にそっと寄り添う占いアプリです。

    今日の運勢、恋愛運、相性診断、相手の気持ち、AIチャット占いまで、月と星の流れからあなたへのメッセージをお届けします。

    恋に迷った夜、不安な朝、少し背中を押してほしい時に。あなた専用の占いが、心をやさしく照らします。
    """

    static let disclaimer = """
    本アプリの占い結果は娯楽・参考情報を目的としたものであり、将来の出来事や結果を保証するものではありません。医療、法律、金融、その他重要な判断については、専門家へご相談ください。
    """
}
