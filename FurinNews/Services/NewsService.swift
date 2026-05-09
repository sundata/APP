import Foundation
import Combine

// MARK: - 网络服务
class NewsService: ObservableObject {
    static let shared = NewsService()
    
    @Published var articles: [NewsArticle] = []
    @Published var isLoading = false
    @Published var hasMore = true
    @Published var error: String?
    @Published var lastUpdated: Date?
    
    #if DEBUG
    private let baseURL = "https://newsnow-backend-327343217815.asia-northeast1.run.app/v1"
    #else
    private let baseURL = "https://newsnow-backend-327343217815.asia-northeast1.run.app/v1"
    #endif
    
    private var cancellables = Set<AnyCancellable>()
    private let cache = NewsCache()
    private var isFetchingImages = false
    static let pageSize = 20
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.waitsForConnectivity = false
        config.httpMaximumConnectionsPerHost = 4
        return URLSession(configuration: config)
    }()
    
    private init() {
        loadCachedData()
        startAutoRefresh()
    }
    
    // MARK: - 获取新闻列表
    func fetchNews(category: NewsCategory? = nil, page: Int = 1, limit: Int = NewsService.pageSize) async {
        await MainActor.run { isLoading = true }
        error = nil
        
        do {
            var components = URLComponents(string: "\(baseURL)/articles")!
            var queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            if let category = category {
                queryItems.append(URLQueryItem(name: "category", value: category.rawValue))
            }
            components.queryItems = queryItems
            
            let request = URLRequest(url: components.url!)
            let (data, response) = try await urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NewsError.invalidResponse
            }
            
            let apiResponse = try JSONDecoder().decode(NewsResponse.self, from: data)
            let newArticles = apiResponse.articles.compactMap { $0.toNewsArticle() }
            
            await MainActor.run {
                if page == 1 {
                    self.articles = newArticles
                } else {
                    let existingIds = Set(self.articles.map { $0.id })
                    let unique = newArticles.filter { !existingIds.contains($0.id) }
                    self.articles.append(contentsOf: unique)
                }
                self.hasMore = apiResponse.hasMore
                self.lastUpdated = Date()
                self.isLoading = false
                self.cache.save(articles: self.articles)
                if page == 1 {
                    self.fetchMissingImagesAfterFirstPaint()
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                if self.articles.isEmpty {
                    loadMockData()
                }
            }
        }
    }
    
    // MARK: - 搜索新闻
    func searchNews(query: String) async -> [NewsArticle] {
        guard !query.isEmpty else { return [] }
        do {
            var components = URLComponents(string: "\(baseURL)/articles")!
            components.queryItems = [
                URLQueryItem(name: "keyword", value: query),
                URLQueryItem(name: "limit", value: "50")
            ]
            let (data, _) = try await self.urlSession.data(from: components.url!)
            let apiResponse = try JSONDecoder().decode(NewsResponse.self, from: data)
            let results = apiResponse.articles.compactMap { $0.toNewsArticle() }
            if !results.isEmpty {
                return results
            }
            // フルキーワードで結果なし → スペース分割して再検索
            let subKeywords = query
                .replacingOccurrences(of: "　", with: " ")
                .split(separator: " ")
                .map(String.init)
                .filter { $0.count >= 2 }
            if subKeywords.count > 1 {
                for kw in subKeywords {
                    var retryComponents = URLComponents(string: "\(baseURL)/articles")!
                    retryComponents.queryItems = [
                        URLQueryItem(name: "keyword", value: kw),
                        URLQueryItem(name: "limit", value: "20")
                    ]
                    let (retryData, _) = try await self.urlSession.data(from: retryComponents.url!)
                    let retryResponse = try JSONDecoder().decode(NewsResponse.self, from: retryData)
                    let retryResults = retryResponse.articles.compactMap { $0.toNewsArticle() }
                    if !retryResults.isEmpty {
                        return retryResults
                    }
                }
            }
            return []
        } catch {
            return articles.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.summary.localizedCaseInsensitiveContains(query) ||
                $0.source.name.localizedCaseInsensitiveContains(query)
            }
        }
    }
    
    // MARK: - カテゴリで検索
    func searchByCategory(_ category: NewsCategory, page: Int = 1, limit: Int = NewsService.pageSize) async -> [NewsArticle] {
        do {
            var components = URLComponents(string: "\(baseURL)/articles")!
            components.queryItems = [
                URLQueryItem(name: "category", value: category.rawValue),
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            let (data, _) = try await self.urlSession.data(from: components.url!)
            let apiResponse = try JSONDecoder().decode(NewsResponse.self, from: data)
            return apiResponse.articles.compactMap { $0.toNewsArticle() }
        } catch {
            guard page == 1 else { return [] }
            return articles.filter { $0.category == category }
        }
    }
    
    // MARK: - 全カテゴリの最新記事を取得（トレンド用）
    func fetchAllLatest(limit: Int = NewsService.pageSize, page: Int = 1) async -> [NewsArticle] {
        do {
            var components = URLComponents(string: "\(baseURL)/articles")!
            components.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)")
            ]
            let (data, _) = try await self.urlSession.data(from: components.url!)
            let apiResponse = try JSONDecoder().decode(NewsResponse.self, from: data)
            let results = apiResponse.articles.compactMap { $0.toNewsArticle() }
            return results.sorted { $0.publishedAt > $1.publishedAt }
        } catch {
            let sorted = articles.sorted { $0.publishedAt > $1.publishedAt }
            let start = max(0, (page - 1) * limit)
            guard start < sorted.count else { return [] }
            return Array(sorted.dropFirst(start).prefix(limit))
        }
    }
    
    // MARK: - 获取分类新闻
    func fetchCategoryNews(_ category: NewsCategory) async -> [NewsArticle] {
        await fetchNews(category: category)
        return articles.filter { $0.category == category }
    }
    
    // MARK: - 自动刷新（每5分钟拉取最新内容）
    private func startAutoRefresh() {
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            Task { await self?.fetchNews() }
        }
    }
    
    // MARK: - 为无图文章抓取OG图片（客户端抓取，避免Cloud Run IP被封锁）
    private func fetchMissingImagesAfterFirstPaint() {
        Task(priority: .background) {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self.fetchMissingImages(limit: 8)
        }
    }

    private func fetchMissingImages(limit: Int) async {
        guard !isFetchingImages else { return }
        let missingImageArticles = articles.filter { $0.imageURL == nil }
        guard !missingImageArticles.isEmpty else { return }
        
        isFetchingImages = true
        defer { isFetchingImages = false }

        for article in missingImageArticles.prefix(limit) {
            if let imageURL = await fetchOGImage(for: article.url) {
                await MainActor.run {
                    if let index = self.articles.firstIndex(where: { $0.id == article.id }) {
                        let old = self.articles[index]
                        self.articles[index] = NewsArticle(
                            id: old.id, title: old.title, summary: old.summary,
                            content: old.content, source: old.source, author: old.author,
                            publishedAt: old.publishedAt, url: old.url,
                            imageURL: imageURL, category: old.category,
                            isRead: old.isRead, isBookmarked: old.isBookmarked
                        )
                        self.cache.save(articles: self.articles)
                    }
                }
                try? await Task.sleep(nanoseconds: 300_000_000)
            }
        }
    }
    
    /// 从文章页面抓取og:image
    private func fetchOGImage(for url: URL) async -> URL? {
        do {
            // NHK: 旧URLを新URLに変換してアクセス
            var fetchURL = url
            if url.host?.contains("nhk.or.jp") == true {
                // http://www3.nhk.or.jp/news/html/20260428/k10015110361000.html
                // → https://news.web.nhk/newsweb/na/na-k10015110361000
                if let newURL = convertNHKURL(url) {
                    fetchURL = newURL
                } else if url.scheme == "http",
                          let httpsURL = URL(string: url.absoluteString.replacingOccurrences(of: "http://", with: "https://")) {
                    fetchURL = httpsURL
                }
            }
            let request = URLRequest(url: fetchURL, timeoutInterval: 10)
            let (data, response) = try await self.urlSession.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let html = String(data: data, encoding: .utf8) else {
                return nil
            }
            
            // 尝试匹配 og:image
            let patterns = [
                // <meta property="og:image" content="...">
                #"meta\s+property="og:image"\s+content="([^"]+)""#,
                // <meta content="..." property="og:image">
                #"meta\s+content="([^"]+)"\s+property="og:image""#,
                // <meta name="twitter:image" content="...">
                #"meta\s+name="twitter:image"\s+content="([^"]+)""#,
                // <meta content="..." name="twitter:image">
                #"meta\s+content="([^"]+)"\s+name="twitter:image""#,
            ]
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
                   let range = Range(match.range(at: 1), in: html) {
                    var imgURLString = String(html[range])
                    
                    // 处理相对路径
                    if imgURLString.hasPrefix("//") {
                        imgURLString = "https:" + imgURLString
                    } else if imgURLString.hasPrefix("/") {
                        let base = "\(fetchURL.scheme ?? "https")://\(fetchURL.host ?? "")"
                        imgURLString = base + imgURLString
                    }
                    
                    // 过滤无效图片
                    let lower = imgURLString.lowercased()
                    let badPatterns = ["favicon", "logo.", "logo-", "icon.", "icon-",
                                       "badge", "button", "spinner", "placeholder",
                                       "gstatic.com/news", "gstatic.com/images"]
                    if badPatterns.contains(where: { lower.contains($0) }) {
                        continue
                    }
                    
                    return URL(string: imgURLString)
                }
            }
        } catch {
            // 静默失败
        }
        return nil
    }
    
    /// NHKの旧URLを新URLに変換
    private func convertNHKURL(_ url: URL) -> URL? {
        let path = url.path
        // /news/html/20260428/k10015110361000.html → k10015110361000
        guard let range = path.range(of: "/(k\\d+)\\.html$", options: .regularExpression),
              let idRange = path.range(of: "k\\d+", options: .regularExpression, range: range) else {
            return nil
        }
        let articleID = String(path[idRange])
        return URL(string: "https://news.web.nhk/newsweb/na/na-\(articleID)")
    }
    
    // MARK: - 缓存管理
    private func loadCachedData() {
        if let cached = cache.load() {
            self.articles = cached
            self.lastUpdated = cache.lastCacheDate
        }
    }
    
    // MARK: - 模拟数据
    func loadMockData() {
        articles = MockDataProvider.createMockArticles()
        lastUpdated = Date()
    }
}

// MARK: - 错误类型
enum NewsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError
    
    var errorDescription: String? {
        switch self {
        case .invalidURL: return "無効なURL"
        case .invalidResponse: return "サーバーエラー"
        case .decodingError: return "データ解析エラー"
        }
    }
}

// MARK: - 数据缓存（简化版：用 Codable 中间结构）
private struct CachedArticle: Codable {
    let id, title, summary, sourceName, sourceWebsite: String
    let author: String
    let publishedAt: Double
    let url: String
    let imageURL: String?
    let category: String
    let isRead, isBookmarked: Bool
}

class NewsCache {
    private let cacheKey = "cached_news_v3"
    private let dateKey = "last_cache_date"
    
    var lastCacheDate: Date? {
        get { UserDefaults.standard.object(forKey: dateKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: dateKey) }
    }
    
    func save(articles: [NewsArticle]) {
        let cached = articles.map { a in
            CachedArticle(
                id: a.id, title: a.title, summary: a.summary,
                sourceName: a.source.name,
                sourceWebsite: a.source.website.absoluteString,
                author: a.author,
                publishedAt: a.publishedAt.timeIntervalSince1970,
                url: a.url.absoluteString,
                imageURL: a.imageURL?.absoluteString,
                category: a.category.rawValue,
                isRead: a.isRead, isBookmarked: a.isBookmarked
            )
        }
        if let encoded = try? JSONEncoder().encode(cached) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
            lastCacheDate = Date()
        }
    }
    
    func load() -> [NewsArticle]? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode([CachedArticle].self, from: data) else {
            return nil
        }
        return cached.compactMap { c -> NewsArticle? in
            guard let artURL = URL(string: c.url) else { return nil }
            let webURL = URL(string: c.sourceWebsite) ?? URL(string: "https://news.yahoo.co.jp")!
            return NewsArticle(
                id: c.id, title: c.title, summary: c.summary,
                source: Source(name: c.sourceName, website: webURL),
                author: c.author,
                publishedAt: Date(timeIntervalSince1970: c.publishedAt),
                url: artURL,
                imageURL: c.imageURL.flatMap { URL(string: $0) },
                category: NewsCategory.from(c.category),
                isRead: c.isRead, isBookmarked: c.isBookmarked
            )
        }
    }
    
    func clear() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: dateKey)
    }
}
