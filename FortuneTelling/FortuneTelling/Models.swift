import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case today
    case love
    case chat
    case calendar
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "ホーム"
        case .today: "今日"
        case .love: "恋愛"
        case .chat: "相談"
        case .calendar: "暦"
        case .profile: "マイページ"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .today: "sparkles"
        case .love: "heart.fill"
        case .chat: "bubble.left.and.bubble.right.fill"
        case .calendar: "calendar"
        case .profile: "person.crop.circle.fill"
        }
    }
}

enum Interest: String, CaseIterable, Identifiable, Codable {
    case love = "恋愛"
    case work = "仕事"
    case money = "金運"
    case health = "健康"
    case relationship = "人間関係"

    var id: String { rawValue }
}

enum Relationship: String, CaseIterable, Identifiable, Codable {
    case crush = "片思い"
    case partner = "恋人"
    case spouse = "夫婦"
    case friend = "友達"
    case workplace = "職場"

    var id: String { rawValue }
}

enum LoveStatus: String, CaseIterable, Identifiable, Codable {
    case crush = "片思い"
    case partner = "恋人あり"
    case reunion = "復縁したい"
    case marriage = "結婚したい"
    case secret = "秘密"

    var id: String { rawValue }
}

enum LoveQuestion: String, CaseIterable, Identifiable {
    case feeling = "彼の気持ちを知りたい"
    case line = "LINEが来るか知りたい"
    case reunion = "復縁できるか知りたい"
    case marriage = "結婚の可能性を知りたい"
    case action = "今動くべきか知りたい"

    var id: String { rawValue }
}

struct FortuneResult: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let overall: Int
    let love: Int
    let work: Int
    let money: Int
    let health: Int
    let luckyColor: String
    let luckyItem: String
    let advice: String
    let detail: String

    init(
        id: UUID = UUID(),
        date: Date,
        overall: Int,
        love: Int,
        work: Int,
        money: Int,
        health: Int,
        luckyColor: String,
        luckyItem: String,
        advice: String,
        detail: String
    ) {
        self.id = id
        self.date = date
        self.overall = overall
        self.love = love
        self.work = work
        self.money = money
        self.health = health
        self.luckyColor = luckyColor
        self.luckyItem = luckyItem
        self.advice = advice
        self.detail = detail
    }
}

struct CompatibilityResult: Codable, Equatable {
    let score: Int
    let feeling: String
    let flow: String
    let contactDay: String
    let avoidAction: String
    let advice: String
}

struct ChatMessage: Identifiable, Codable, Equatable {
    enum Sender: String, Codable {
        case user
        case app
    }

    let id: UUID
    let sender: Sender
    let text: String

    init(id: UUID = UUID(), sender: Sender, text: String) {
        self.id = id
        self.sender = sender
        self.text = text
    }
}

struct UserProfile: Codable, Equatable {
    var nickname = "ゆい"
    var birthday = Calendar.current.date(from: DateComponents(year: 1998, month: 4, day: 12)) ?? .now
    var gender = "未設定"
    var bloodType = "A"
    var loveStatus: LoveStatus = .secret
    var interests: Set<Interest> = [.love, .work]
}

struct BirthFortune: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let summary: String
    let advice: String
}

struct PremiumPlan: Identifiable, Equatable {
    let id: String
    let title: String
    let price: String
    let description: String

    static let monthlyBasic = PremiumPlan(id: "monthly_480", title: "月額ライト", price: "480円/月", description: "広告非表示、AI相談無制限、占い履歴保存")
    static let monthlyPlus = PremiumPlan(id: "monthly_980", title: "月額プレミアム", price: "980円/月", description: "詳細恋愛占い、相手の本音診断、復縁・結婚時期占い")
    static let annual = PremiumPlan(id: "annual_4800", title: "年額プラン", price: "4,800円/年", description: "月額よりお得に全機能を利用")

    static let all = [monthlyBasic, monthlyPlus, annual]
}

struct OmikujiResult: Identifiable, Codable, Equatable {
    let id: UUID
    let rank: String
    let message: String
    let charm: String

    init(id: UUID = UUID(), rank: String, message: String, charm: String) {
        self.id = id
        self.rank = rank
        self.message = message
        self.charm = charm
    }
}
