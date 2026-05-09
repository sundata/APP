import Foundation
import Combine

@MainActor
class NewsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var articles: [NewsArticle] = []
    @Published var filteredArticles: [NewsArticle] = []
    @Published var topStories: [NewsArticle] = []
    @Published var isLoading = false
    @Published var isCategoryLoading = false
    @Published var isRefreshing = false
    @Published var error: String?
    @Published var lastUpdated: Date?
    @Published var selectedCategory: NewsCategory? = nil
    @Published var searchQuery = ""
    @Published var searchResults: [NewsArticle] = []
    @Published var bookmarkedArticles: [NewsArticle] = []
    @Published var currentPage = 1
    @Published var hasMore = true
    
    private let service = NewsService.shared
    private var cancellables = Set<AnyCancellable>()
    private var isSearchingByCategory = false  // カテゴリ検索中はキーワード検索を抑制
    private var categoryLoadTask: Task<Void, Never>?
    private var categoryPrefetchTask: Task<Void, Never>?
    private var feedCache: [String: [NewsArticle]] = [:]
    private var activeFeedKey = "all"
    private var didPrefetchCategories = false
    
    // MARK: - Init
    init() {
        setupBindings()
        Task { await loadInitialData() }
    }
    
    // MARK: - Bindings
    private func setupBindings() {
        // 监听 service 数据变化
        service.$articles
            .receive(on: RunLoop.main)
            .sink { [weak self] articles in
                guard let self else { return }
                if let selectedCategory = self.selectedCategory,
                   selectedCategory != .trending,
                   self.activeFeedKey == selectedCategory.rawValue,
                   !articles.isEmpty,
                   articles.contains(where: { $0.category != selectedCategory }) {
                    self.feedCache["all"] = articles
                    return
                }
                self.articles = articles
                self.restoreBookmarks()
                self.applyFilter()
                self.updateTopStories()
                self.updateBookmarks()
                self.feedCache[self.activeFeedKey] = self.articles
            }
            .store(in: &cancellables)
        
        service.$isLoading
            .receive(on: RunLoop.main)
            .assign(to: &$isLoading)
        
        service.$hasMore
            .receive(on: RunLoop.main)
            .assign(to: &$hasMore)
        
        service.$error
            .receive(on: RunLoop.main)
            .assign(to: &$error)
        
        service.$lastUpdated
            .receive(on: RunLoop.main)
            .assign(to: &$lastUpdated)
        
        // 搜索防抖（500ms，等待用户输入完毕后再请求API）
        $searchQuery
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
        
        // 分类变化时过滤
        $selectedCategory
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFilter()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    func loadInitialData() async {
        await service.fetchNews()
        feedCache["all"] = articles
        prefetchCommonCategories()
    }
    
    func refresh() async {
        isRefreshing = true
        currentPage = 1
        hasMore = true
        activeFeedKey = cacheKey(for: selectedCategory)
        let category = selectedCategory == .trending ? nil : selectedCategory
        await service.fetchNews(category: category, page: 1)
        isRefreshing = false
    }
    
    func loadMore() async {
        guard !isLoading, hasMore else { return }
        currentPage += 1
        let category = selectedCategory == .trending ? nil : selectedCategory
        activeFeedKey = cacheKey(for: selectedCategory)
        await service.fetchNews(category: category, page: currentPage)
    }
    
    // MARK: - Filter
    func applyFilter() {
        if let category = selectedCategory {
            // トレンドは全カテゴリの最新記事を表示（DB上のtrendingカテゴリは記事が少ないため）
            if category == .trending {
                filteredArticles = Array(articles
                    .sorted { $0.publishedAt > $1.publishedAt }
                    .prefix(NewsService.pageSize))
            } else {
                filteredArticles = articles.filter { $0.category == category }
            }
        } else {
            filteredArticles = articles
        }
    }
    
    func selectCategory(_ category: NewsCategory?) {
        categoryLoadTask?.cancel()
        let key = cacheKey(for: category)
        activeFeedKey = key
        isCategoryLoading = true
        selectedCategory = category
        currentPage = 1
        hasMore = true
        
        if let cached = feedCache[key], !cached.isEmpty {
            articles = cached
            restoreBookmarks()
            applyFilter()
            updateTopStories()
            updateBookmarks()
        }

        categoryLoadTask = Task {
            let categoryForRequest = category == .trending ? nil : category
            await service.fetchNews(category: categoryForRequest, page: 1)
            guard !Task.isCancelled else { return }
            feedCache[key] = articles
            isCategoryLoading = false
        }
    }

    private func cacheKey(for category: NewsCategory?) -> String {
        category?.rawValue ?? "all"
    }

    private func prefetchCommonCategories() {
        guard !didPrefetchCategories else { return }
        didPrefetchCategories = true
        categoryPrefetchTask?.cancel()
        categoryPrefetchTask = Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            let categories: [NewsCategory] = [.politician, .celebrity, .sports, .business, .overseas]
            for category in categories {
                guard !Task.isCancelled else { return }
                let key = cacheKey(for: category)
                guard feedCache[key]?.isEmpty ?? true else { continue }
                let results = await service.searchByCategory(category, page: 1, limit: NewsService.pageSize)
                guard !Task.isCancelled, !results.isEmpty else { continue }
                feedCache[key] = results
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }
    }
    
    // MARK: - Search
    private func performSearch(query: String) {
        // カテゴリ検索中はキーワード検索をスキップ
        guard !isSearchingByCategory else { return }
        
        if query.isEmpty {
            searchResults = []
            return
        }
        // 先从本地已加载的数据中搜索（即时反馈）
        // 对每个词分别匹配（OR 逻辑），提高命中率
        let keywords = query
            .replacingOccurrences(of: "　", with: " ")
            .split(separator: " ")
            .map(String.init)
            .filter { $0.count >= 1 }
        
        let localResults: [NewsArticle]
        if keywords.count > 1 {
            // 多关键词：任意一个匹配即可
            localResults = articles.filter { article in
                keywords.contains { kw in
                    article.title.localizedCaseInsensitiveContains(kw) ||
                    article.summary.localizedCaseInsensitiveContains(kw) ||
                    article.source.name.localizedCaseInsensitiveContains(kw) ||
                    article.category.displayName.localizedCaseInsensitiveContains(kw)
                }
            }
        } else {
            // 单关键词：在 title/summary/source/category 中搜索
            localResults = articles.filter {
                $0.title.localizedCaseInsensitiveContains(query) ||
                $0.summary.localizedCaseInsensitiveContains(query) ||
                $0.source.name.localizedCaseInsensitiveContains(query) ||
                $0.category.displayName.localizedCaseInsensitiveContains(query)
            }
        }
        searchResults = localResults
        
        // 同时请求后端API搜索（更全面的结果）
        Task {
            var apiResults = await service.searchNews(query: query)
            // APIも結果なし → キーワードを分割して再検索
            if apiResults.isEmpty && localResults.isEmpty && keywords.count > 1 {
                // 各キーワードで個別に検索
                for kw in keywords where kw.count >= 2 {
                    let partial = await service.searchNews(query: kw)
                    if !partial.isEmpty {
                        apiResults = partial
                        break
                    }
                }
            }
            if !apiResults.isEmpty {
                searchResults = apiResults
            }
        }
    }
    
    /// カテゴリで検索（検索画面の「カテゴリで探す」用）
    func searchByCategory(_ category: NewsCategory) async {
        isSearchingByCategory = true
        searchQuery = category.displayName
        // trending は全カテゴリの最新記事を表示（API の category=trending は記事が少ないため）
        let results: [NewsArticle]
        if category == .trending {
            results = await service.fetchAllLatest(limit: NewsService.pageSize)
        } else {
            results = await service.searchByCategory(category)
        }
        await MainActor.run {
            searchResults = results
            isSearchingByCategory = false
        }
    }
    
    /// カテゴリ画面用の記事読み込み
    func loadCategoryArticles(_ category: NewsCategory, page: Int = 1) async -> [NewsArticle] {
        // trending は全カテゴリの最新記事を表示
        if category == .trending {
            return await service.fetchAllLatest(limit: 50, page: page)
        }
        // その他のカテゴリは API から取得
        return await service.searchByCategory(category, page: page)
    }
    
    // MARK: - Top Stories
    private func updateTopStories() {
        // 只取有有效图片的文章作为 top stories
        topStories = Array(articles.filter { $0.validImageURL != nil }.prefix(5))
    }
    
    // MARK: - Bookmarks
    private func updateBookmarks() {
        bookmarkedArticles = articles.filter { $0.isBookmarked }
    }
    
    func toggleBookmark(article: NewsArticle) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            let updated = articles[index]
            let newArticle = NewsArticle(
                id: updated.id,
                title: updated.title,
                summary: updated.summary,
                content: updated.content,
                source: updated.source,
                author: updated.author,
                publishedAt: updated.publishedAt,
                url: updated.url,
                imageURL: updated.imageURL,
                category: updated.category,
                isRead: updated.isRead,
                isBookmarked: !updated.isBookmarked
            )
            articles[index] = newArticle
            applyFilter()
            updateBookmarks()
            saveBookmarks()
        }
    }
    
    func markAsRead(article: NewsArticle) {
        if let index = articles.firstIndex(where: { $0.id == article.id }) {
            let old = articles[index]
            articles[index] = NewsArticle(
                id: old.id, title: old.title, summary: old.summary,
                content: old.content, source: old.source, author: old.author,
                publishedAt: old.publishedAt, url: old.url,
                imageURL: old.imageURL, category: old.category,
                isRead: true, isBookmarked: old.isBookmarked
            )
            applyFilter()
        }
    }
    
    // MARK: - Persistence
    private let bookmarkKey = "bookmarked_ids"
    
    private func saveBookmarks() {
        let ids = articles.filter { $0.isBookmarked }.map { $0.id }
        UserDefaults.standard.set(ids, forKey: bookmarkKey)
    }
    
    /// 保存済みIDを記事リストに反映
    private func restoreBookmarks() {
        guard let savedIds = UserDefaults.standard.stringArray(forKey: bookmarkKey) else { return }
        let idSet = Set(savedIds)
        for i in articles.indices where idSet.contains(articles[i].id) {
            let old = articles[i]
            guard !old.isBookmarked else { continue }
            articles[i] = NewsArticle(
                id: old.id, title: old.title, summary: old.summary,
                content: old.content, source: old.source, author: old.author,
                publishedAt: old.publishedAt, url: old.url,
                imageURL: old.imageURL, category: old.category,
                isRead: old.isRead, isBookmarked: true
            )
        }
    }
    
    // MARK: - Formatting Helpers
    func formattedDate(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)
        if diff < 3600 {
            let mins = Int(diff / 60)
            return "\(mins)分前"
        } else if diff < 86400 {
            let hrs = Int(diff / 3600)
            return "\(hrs)時間前"
        } else {
            let fmt = DateFormatter()
            fmt.locale = Locale(identifier: "ja_JP")
            fmt.dateFormat = "M月d日"
            return fmt.string(from: date)
        }
    }
    
    // MARK: - Dev Helper
    func loadDemoData() {
        service.loadMockData()
    }
}
