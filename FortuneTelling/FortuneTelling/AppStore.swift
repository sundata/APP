import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published var profile: UserProfile {
        didSet { save(profile, key: Keys.profile) }
    }

    @Published var history: [FortuneResult] {
        didSet { save(history, key: Keys.history) }
    }

    @Published var chatMessages: [ChatMessage] {
        didSet { save(chatMessages, key: Keys.chatMessages) }
    }

    @Published var isPremium: Bool {
        didSet { defaults.set(isPremium, forKey: Keys.isPremium) }
    }

    @Published var selectedPlanID: String {
        didSet { defaults.set(selectedPlanID, forKey: Keys.selectedPlanID) }
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var dailyConsultDateKey: String {
        didSet { defaults.set(dailyConsultDateKey, forKey: Keys.dailyConsultDateKey) }
    }

    @Published var dailyConsultUsed: Int {
        didSet { defaults.set(dailyConsultUsed, forKey: Keys.dailyConsultUsed) }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    @Published var dailyOmikujiDateKey: String {
        didSet { defaults.set(dailyOmikujiDateKey, forKey: Keys.dailyOmikujiDateKey) }
    }

    @Published var dailyOmikujiResult: OmikujiResult? {
        didSet { save(dailyOmikujiResult, key: Keys.dailyOmikujiResult) }
    }

    private let defaults = UserDefaults.standard

    init() {
        profile = Self.load(UserProfile.self, key: Keys.profile) ?? UserProfile()
        history = Self.load([FortuneResult].self, key: Keys.history) ?? []
        chatMessages = Self.load([ChatMessage].self, key: Keys.chatMessages) ?? [
            ChatMessage(sender: .app, text: "不安になりますよね。恋のこと、仕事のこと、今の気持ちをそのまま書いてください。月の流れに重ねて、やさしく読み解きます。")
        ]
        isPremium = defaults.bool(forKey: Keys.isPremium)
        selectedPlanID = defaults.string(forKey: Keys.selectedPlanID) ?? PremiumPlan.monthlyBasic.id
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        dailyConsultDateKey = defaults.string(forKey: Keys.dailyConsultDateKey) ?? Self.todayKey()
        dailyConsultUsed = defaults.integer(forKey: Keys.dailyConsultUsed)
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        dailyOmikujiDateKey = defaults.string(forKey: Keys.dailyOmikujiDateKey) ?? ""
        dailyOmikujiResult = Self.load(OmikujiResult?.self, key: Keys.dailyOmikujiResult) ?? nil
        resetDailyUsageIfNeeded()
    }

    var today: FortuneResult {
        FortuneEngine.todayFortune(for: profile)
    }

    var selectedPlan: PremiumPlan {
        PremiumPlan.all.first(where: { $0.id == selectedPlanID }) ?? .monthlyBasic
    }

    var consultLimit: Int {
        isPremium ? Int.max : 3
    }

    var remainingConsultations: Int {
        if isPremium { return Int.max }
        return max(consultLimit - dailyConsultUsed, 0)
    }

    var shouldShowAds: Bool {
        !isPremium
    }

    func saveTodayFortune() {
        let result = today
        guard !history.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: result.date) }) else {
            return
        }
        history.insert(result, at: 0)
        history = Array(history.prefix(isPremium ? 120 : 7))
    }

    func sendConsultation(_ question: String) {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, isPremium || remainingConsultations > 0 else { return }
        if !isPremium {
            dailyConsultUsed += 1
        }
        chatMessages.append(ChatMessage(sender: .user, text: trimmed))
        chatMessages.append(ChatMessage(sender: .app, text: FortuneEngine.answer(for: trimmed, remainingCount: remainingConsultations, turn: chatMessages.count)))
    }

    func drawOmikuji() {
        let key = Self.todayKey()
        guard isPremium || dailyOmikujiDateKey != key || dailyOmikujiResult == nil else { return }
        dailyOmikujiDateKey = key
        dailyOmikujiResult = FortuneEngine.omikuji(for: profile)
    }

    func purchaseSelectedPlan() {
        isPremium = true
    }

    func restorePurchase() {
        isPremium = true
    }

    func cancelPremiumForTesting() {
        isPremium = false
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
    }

    func resetOnboardingForTesting() {
        hasCompletedOnboarding = false
    }

    func resetDailyUsageIfNeeded() {
        let key = Self.todayKey()
        if dailyConsultDateKey != key {
            dailyConsultDateKey = key
            dailyConsultUsed = 0
        }
        if dailyOmikujiDateKey != key {
            dailyOmikujiResult = nil
        }
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            print("[AppStore] 保存に失敗 key=\(key): \(error)")
        }
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            print("[AppStore] 読み込みに失敗 key=\(key): \(error)")
            return nil
        }
    }

    private static func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: .now)
    }
}

private enum Keys {
    static let profile = "fortune.profile"
    static let history = "fortune.history"
    static let chatMessages = "fortune.chatMessages"
    static let isPremium = "fortune.isPremium"
    static let selectedPlanID = "fortune.selectedPlanID"
    static let notificationsEnabled = "fortune.notificationsEnabled"
    static let dailyConsultDateKey = "fortune.dailyConsultDateKey"
    static let dailyConsultUsed = "fortune.dailyConsultUsed"
    static let hasCompletedOnboarding = "fortune.hasCompletedOnboarding"
    static let dailyOmikujiDateKey = "fortune.dailyOmikujiDateKey"
    static let dailyOmikujiResult = "fortune.dailyOmikujiResult"
}
