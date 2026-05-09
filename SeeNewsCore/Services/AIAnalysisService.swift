import Foundation
import Combine

// MARK: - AI分析サービス
@MainActor
class AIAnalysisService: ObservableObject {
    static let shared = AIAnalysisService()
    
    @Published var analyses: [String: AIAnalysis] = [:]  // articleId -> AIAnalysis
    @Published var isAnalyzing = false
    @Published var error: String?
    
    #if DEBUG
    private let baseURL = "https://newsnow-backend-327343217815.asia-northeast1.run.app/v1"
    #else
    private let baseURL = "https://newsnow-backend-327343217815.asia-northeast1.run.app/v1"
    #endif
    
    private let userManager = UserManager.shared
    
    private init() {
        loadCachedAnalyses()
    }
    
    // MARK: - AI分析リクエスト
    func analyzeArticle(
        _ article: NewsArticle,
        includeDeepAnalysis: Bool = false,
        userPlan: SubscriptionPlan = .free,
        forceRefresh: Bool = false
    ) async -> AIAnalysis? {
        // Pro機能チェック
        if includeDeepAnalysis && userPlan == .free {
            await MainActor.run {
                self.error = "この機能はPro限定です"
            }
            return nil
        }
        
        // キャッシュチェック（forceRefresh=falseの場合のみ）
        if !forceRefresh, let cached = analyses[article.id] {
            // キャッシュには深度分析がない場合、Pro限定部分を追加
            if includeDeepAnalysis && cached.deepAnalysis == nil {
                let deepAnalysis = await fetchDeepAnalysis(articleId: article.id, article: article)
                var updated = cached
                updated.deepAnalysis = deepAnalysis
                return updated
            }
            return cached
        }
        
        await MainActor.run { isAnalyzing = true }
        error = nil
        
        do {
            let analysis = try await requestAnalysis(
                article: article,
                includeDeepAnalysis: includeDeepAnalysis,
                forceRefresh: forceRefresh
            )
            
            await MainActor.run {
                self.analyses[article.id] = analysis
                self.isAnalyzing = false
                self.cacheAnalyses()
            }
            
            return analysis
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isAnalyzing = false
            }
            return nil
        }
    }
    
    // MARK: - API呼び出し
    private func requestAnalysis(
        article: NewsArticle,
        includeDeepAnalysis: Bool,
        forceRefresh: Bool = false
    ) async throws -> AIAnalysis {
        // 基本分析を取得
        var components = URLComponents(string: "\(baseURL)/ai/analyze")!
        components.queryItems = [
            URLQueryItem(name: "article_id", value: article.id),
            URLQueryItem(name: "title", value: article.title),
            URLQueryItem(name: "summary", value: article.summary),
            URLQueryItem(name: "content", value: article.summary),  // 詳細内容がない場合は summary を使用
            URLQueryItem(name: "force_refresh", value: forceRefresh ? "true" : "false")  // ← 強制更新パラメータ
        ]
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        // ✅ 设置超时时间（120秒给 OpenAI API 充足时间）
        request.timeoutInterval = 120
        request.cachePolicy = .useProtocolCachePolicy
        
        // ── 認証ヘッダーを追加 ──
        let headers = userManager.getAuthHeaders()
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 150  // 总超时 150 秒
        let session = URLSession(configuration: config)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AIAnalysisService", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard httpResponse.statusCode == 200 else {
            // ✅ 更详细的错误信息
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ AI分析API错误 Status: \(httpResponse.statusCode), Body: \(errorMsg)")
            let message = httpResponse.statusCode == 202
                ? "真实AI分析を準備中です。少し待ってから再試行してください。"
                : "Status: \(httpResponse.statusCode)"
            throw NSError(domain: "AIAnalysisService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        let decoder = JSONDecoder()
        let analysisResponse = try decoder.decode(AIAnalysisResponse.self, from: data)
        
        // 基本分析をモデルに変換
        var analysis = AIAnalysis(
            articleId: article.id,
            summary: analysisResponse.summary,
            keyPoints: analysisResponse.threePoints,
            importance: analysisResponse.importance,
            deepAnalysis: nil
        )
        
        // Pro機能: 深度分析を取得
        if includeDeepAnalysis {
            if let deepAnalysis = await fetchDeepAnalysis(articleId: article.id, article: article) {
                analysis.deepAnalysis = deepAnalysis
            }
        }
        
        return analysis
    }
    
    // MARK: - API レスポンスモデル
    private struct AIAnalysisResponse: Decodable {
        let articleId: String
        let summary: String
        let threePoints: [String]
        let importance: String
        let cached: Bool
        
        enum CodingKeys: String, CodingKey {
            case articleId
            case summary
            case threePoints
            case importance
            case cached
        }
    }
    
    private struct DeepAnalysisResponse: Decodable {
        let articleId: String
        let impactAnalysis: String
        let futureOutlook: String
        let actionAdvice: String
        
        enum CodingKeys: String, CodingKey {
            case articleId
            case impactAnalysis
            case futureOutlook
            case actionAdvice
        }
    }
    
    // MARK: - 深度分析の取得
    private func fetchDeepAnalysis(
        articleId: String,
        article: NewsArticle
    ) async -> DeepAnalysis? {
        do {
            var components = URLComponents(string: "\(baseURL)/ai/deep-analyze")!
            components.queryItems = [
                URLQueryItem(name: "article_id", value: articleId),
                URLQueryItem(name: "title", value: article.title),
                URLQueryItem(name: "summary", value: article.summary),
                URLQueryItem(name: "content", value: article.summary)
            ]
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = "POST"
            // ✅ 设置超时时间（深度分析也需要时间）
            request.timeoutInterval = 60
            
            // ── 認証ヘッダーを追加 ──
            let headers = userManager.getAuthHeaders()
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
            
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 60
            config.timeoutIntervalForResource = 90  // 深度分析总超时 90 秒
            let session = URLSession(configuration: config)
            
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                return nil
            }
            
            let decoder = JSONDecoder()
            let deepResponse = try decoder.decode(DeepAnalysisResponse.self, from: data)
            
            // DeepAnalysisResponse を DeepAnalysis に変換
            return DeepAnalysis(
                impactAnalysis: deepResponse.impactAnalysis,
                futurePredict: deepResponse.futureOutlook,  // futureOutlook -> futurePredict
                actionAdvice: deepResponse.actionAdvice
            )
        } catch {
            return nil
        }
    }
    
    // MARK: - キャッシュ管理
    private func cacheAnalyses() {
        if let encoded = try? JSONEncoder().encode(analyses) {
            UserDefaults.standard.set(encoded, forKey: "AIAnalysesCache")
        }
    }
    
    private func loadCachedAnalyses() {
        if let data = UserDefaults.standard.data(forKey: "AIAnalysesCache"),
           let decoded = try? JSONDecoder().decode([String: AIAnalysis].self, from: data) {
            self.analyses = decoded
        }
    }
    
    // MARK: - キャッシュクリア
    func clearCache() {
        analyses.removeAll()
        UserDefaults.standard.removeObject(forKey: "AIAnalysesCache")
    }
    
    // MARK: - 特定記事のキャッシュクリア
    func clearCacheForArticle(_ article: NewsArticle) {
        analyses.removeValue(forKey: article.id)
        cacheAnalyses()
    }
    
    // MARK: - 最新の分析を強制取得
    func refreshAnalysis(
        _ article: NewsArticle,
        includeDeepAnalysis: Bool = false,
        userPlan: SubscriptionPlan = .free
    ) async -> AIAnalysis? {
        // キャッシュから削除
        clearCacheForArticle(article)
        // 新規分析をリクエスト（forceRefresh=true）
        return await analyzeArticle(article, includeDeepAnalysis: includeDeepAnalysis, userPlan: userPlan, forceRefresh: true)
    }
}
