import SwiftUI
import Foundation

// MARK: - 新闻数据模型
struct NewsArticle: Identifiable, Hashable {
    let id: String           // API 返回的字符串 ID
    let title: String
    let summary: String
    let content: String?
    let source: Source
    let author: String
    let publishedAt: Date
    let url: URL
    let imageURL: URL?
    let category: NewsCategory
    var isRead: Bool
    var isBookmarked: Bool
    
    init(
        id: String = UUID().uuidString,
        title: String,
        summary: String,
        content: String? = nil,
        source: Source,
        author: String = "",
        publishedAt: Date = Date(),
        url: URL,
        imageURL: URL? = nil,
        category: NewsCategory = .general,
        isRead: Bool = false,
        isBookmarked: Bool = false
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.content = content
        self.source = source
        self.author = author
        self.publishedAt = publishedAt
        self.url = url
        self.imageURL = imageURL
        self.category = category
        self.isRead = isRead
        self.isBookmarked = isBookmarked
    }
}

// MARK: - 来源信息
struct Source: Hashable {
    let name: String
    let logoURL: URL?
    let website: URL
    
    init(name: String, logoURL: URL? = nil, website: URL) {
        self.name = name
        self.logoURL = logoURL
        self.website = website
    }
}

// MARK: - 新闻分类
enum NewsCategory: String, CaseIterable, Codable {
    case general = "general"
    case celebrity = "celebrity"
    case politician = "politician"
    case sports = "sports"
    case business = "business"
    case overseas = "overseas"
    case trending = "trending"
    
    /// 日语显示名
    var displayName: String {
        switch self {
        case .general:    return "総合"
        case .celebrity:  return "芸能人"
        case .politician: return "政治家"
        case .sports:     return "スポーツ"
        case .business:   return "ビジネス"
        case .overseas:   return "海外"
        case .trending:   return "トレンド"
        }
    }
    
    var icon: String {
        switch self {
        case .general:    return "newspaper.fill"
        case .celebrity:  return "star.fill"
        case .politician: return "building.2.fill"
        case .sports:     return "sportscourt.fill"
        case .business:   return "briefcase.fill"
        case .overseas:   return "globe"
        case .trending:   return "flame.fill"
        }
    }
    
    /// カテゴリ別のカラー
    var color: Color {
        switch self {
        case .general:    return .blue
        case .celebrity:  return .pink
        case .politician: return .indigo
        case .sports:     return .green
        case .business:   return .orange
        case .overseas:   return .cyan
        case .trending:   return .red
        }
    }
    
    /// 从 API 返回的 rawValue 字符串安全初始化
    static func from(_ raw: String) -> NewsCategory {
        NewsCategory(rawValue: raw) ?? .general
    }
}

// MARK: - API 响应解码模型（与后端 JSON 完全匹配）
struct APIArticle: Codable {
    let id: String
    let title: String
    let summary: String
    let source: APISource
    let author: String
    let publishedAt: String
    let url: String
    let imageURL: String?
    let category: String
    let isRead: Bool
    let isBookmarked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, title, summary, source, author
        case publishedAt, url, category, isRead, isBookmarked
        case imageURL
    }
}

struct APISource: Codable {
    let name: String
    let logoURL: String?
    let website: String
}

struct NewsResponse: Codable {
    let articles: [APIArticle]
    let total: Int
    let page: Int
    let hasMore: Bool
}

// MARK: - APIArticle → NewsArticle 转换
extension APIArticle {
    func toNewsArticle() -> NewsArticle? {
        guard let articleURL = URL(string: url) else { return nil }
        let imgURL = imageURL.flatMap { URL(string: $0) }
        let webURL = URL(string: source.website) ?? URL(string: "https://news.yahoo.co.jp")!
        
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = dateFormatter.date(from: publishedAt)
            ?? ISO8601DateFormatter().date(from: publishedAt)
            ?? Date()
        
        return NewsArticle(
            id: id,
            title: title,
            summary: summary,
            source: Source(
                name: source.name,
                logoURL: source.logoURL.flatMap { URL(string: $0) },
                website: webURL
            ),
            author: author,
            publishedAt: date,
            url: articleURL,
            imageURL: imgURL,
            category: NewsCategory.from(category),
            isRead: isRead,
            isBookmarked: isBookmarked
        )
    }
}

// MARK: - 收藏夹模型
struct BookmarkFolder: Identifiable, Codable {
    let id: UUID
    let name: String
    var articleIds: [String]
    
    init(id: UUID = UUID(), name: String, articleIds: [String] = []) {
        self.id = id
        self.name = name
        self.articleIds = articleIds
    }
}

// MARK: - 图片有效性验证
extension NewsArticle {
    /// 过滤掉 favicon/logo 等无效图片，保留文章缩略图
    var validImageURL: URL? {
        guard let url = imageURL else { return nil }
        let urlStr = url.absoluteString.lowercased()
        let badPatterns = [
            "favicon", "logo.", "logo-", "icon.", "icon-",
            "badge", "button", "spinner", "placeholder",
            "gstatic.com/news", "gstatic.com/images",
        ]
        for pat in badPatterns {
            if urlStr.contains(pat) {
                return nil
            }
        }
        return url
    }
}

// MARK: - AI分析モデル
struct AIAnalysis: Identifiable, Codable {
    let id: String
    let articleId: String
    let summary: String  // 一言まとめ
    let keyPoints: [String]  // 3つのポイント（最大3つ）
    let importance: String  // なぜ重要か
    var deepAnalysis: DeepAnalysis?  // Pro限定
    let createdAt: Date
    
    init(
        id: String = UUID().uuidString,
        articleId: String,
        summary: String,
        keyPoints: [String],
        importance: String,
        deepAnalysis: DeepAnalysis? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.articleId = articleId
        self.summary = summary
        self.keyPoints = Array(keyPoints.prefix(3))
        self.importance = importance
        self.deepAnalysis = deepAnalysis
        self.createdAt = createdAt
    }
}

// MARK: - Pro限定の深度分析
struct DeepAnalysis: Codable {
    let impactAnalysis: String  // 影響分析
    let futurePredict: String   // 今後の予測
    let actionAdvice: String    // 行動提案
}

// MARK: - サブスクリプション計画
enum SubscriptionPlan: String, Codable {
    case free = "free"
    case pro = "pro"
    
    var displayName: String {
        switch self {
        case .free:
            return "無料プラン"
        case .pro:
            return "Proプラン"
        }
    }
    
    var price: String {
        switch self {
        case .free:
            return "無料"
        case .pro:
            return "¥680/月"
        }
    }
    
    var aiAnalysisLimit: Int? {
        switch self {
        case .free:
            return 3  // 1日3回
        case .pro:
            return nil  // 無制限
        }
    }
    
    var hasDeepAnalysis: Bool {
        switch self {
        case .free:
            return false
        case .pro:
            return true
        }
    }
    
    var hasAds: Bool {
        switch self {
        case .free:
            return true
        case .pro:
            return false
        }
    }
}

// MARK: - ユーザーのサブスクリプション状態
struct UserSubscription: Codable {
    var plan: SubscriptionPlan = .free
    var proExpiryDate: Date?  // Pro期限
    var aiAnalysisUsedToday: Int = 0
    var dailyResetDate: Date = Date()
    
    var isPro: Bool {
        guard plan == .pro else { return false }
        guard let expiry = proExpiryDate else { return true }
        return Date() < expiry
    }
    
    var canUseAIAnalysis: Bool {
        // 新しい日になったら0にリセット
        let calendar = Calendar.current
        if !calendar.isDateInToday(dailyResetDate) {
            return true  // UIで呼ぶ前にリセットしてもらう
        }
        
        if plan == .pro {
            return true
        }
        return aiAnalysisUsedToday < 3
    }
    
    mutating func incrementAIAnalysisUsage() {
        aiAnalysisUsedToday += 1
    }
    
    mutating func resetDailyUsage() {
        let calendar = Calendar.current
        if !calendar.isDateInToday(dailyResetDate) {
            aiAnalysisUsedToday = 0
            dailyResetDate = Date()
        }
    }
}
