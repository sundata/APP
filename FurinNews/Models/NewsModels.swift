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

/// 同じ出来事を扱う複数メディアの記事をまとめた、即時生成のイベント。
struct NewsEvent: Identifiable, Hashable {
    let id: String
    let headline: NewsArticle
    let relatedArticles: [NewsArticle]

    var sourceCount: Int {
        Set(([headline] + relatedArticles).map(\.source.name)).count
    }

    var latestUpdate: Date {
        ([headline] + relatedArticles).map(\.publishedAt).max() ?? headline.publishedAt
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

    /// プレースホルダー用の装飾アイコン
    var decorativeIcon: String {
        switch self {
        case .general:    return "text.bubble.fill"
        case .celebrity:  return "sparkles"
        case .politician: return "building.columns.fill"
        case .sports:     return "figure.run"
        case .business:   return "chart.bar.fill"
        case .overseas:   return "globe.americas.fill"
        case .trending:   return "flame.circle.fill"
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
        
        let date = ArticleDateFormatters.fractionalISO8601.date(from: publishedAt)
            ?? ArticleDateFormatters.iso8601.date(from: publishedAt)
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

private enum ArticleDateFormatters {
    static let fractionalISO8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let iso8601 = ISO8601DateFormatter()
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
    /// AIを待たず、カテゴリと本文からすぐ表示できる「なぜ重要か」。
    var instantInsight: String {
        switch category {
        case .business:
            return "暮らし・企業活動・市場への影響を確認したいニュースです"
        case .politician:
            return "制度や社会の動きにつながる可能性があります"
        case .sports:
            return "結果だけでなく、今後の日程や順位への影響に注目です"
        case .overseas:
            return "国際情勢や経済への波及を追う価値があります"
        case .celebrity:
            return "話題の背景と本人・関係者の発表を確認できます"
        case .trending, .general:
            return "いま注目が集まっている背景を短時間で把握できます"
        }
    }

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
