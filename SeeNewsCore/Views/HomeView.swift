import SwiftUI

// MARK: - ホーム画面
struct HomeView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var showSubscriptionSheet = false
    @State private var subscriptionPromptMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // ── カテゴリチップ ──
                    CategoryChipsView()
                        .padding(.top, 8)
                        .id("categories")  // スクロール位置の安定化
                    
                    // ── 広告バナー（無料プランのみ） ──
                    if viewModel.userSubscription.plan == .free {
                        AdBannerView()
                            .environmentObject(viewModel)
                            .padding(.vertical, 8)
                    }
                    
                    if viewModel.isLoading && viewModel.articles.isEmpty {
                        LoadingSkeletonView()
                    } else if viewModel.filteredArticles.isEmpty {
                        EmptyStateView()
                    } else {
                        // ── ニュースリスト ──
                        LazyVStack(spacing: 0) {
                            ForEach(Array(viewModel.filteredArticles.enumerated()), id: \.element.id) { index, article in
                                NewsRowView(article: article)
                                    .contextMenu {
                                        ArticleContextMenu(article: article)
                                    }
                                
                                Divider().padding(.leading, 16)
                                
                                // 3記事ごとに広告を表示（無料プランのみ）
                                if viewModel.userSubscription.plan == .free && (index + 1) % 3 == 0 && index < viewModel.filteredArticles.count - 1 {
                                    AdListItemView()
                                        .padding(.vertical, 8)
                                }
                                
                                // 最後の記事の時点でロード判定
                                if index == viewModel.filteredArticles.count - 1 && index > 4 {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear {
                                            // カテゴリ選択時も自動ロードを有効化
                                            if viewModel.hasMore && !viewModel.isLoading {
                                                Task { await viewModel.loadMore() }
                                            }
                                        }
                                }
                            }
                            
                            // ──ローディングインジケーター（追加読み込み中）──
                            if viewModel.isLoading && !viewModel.articles.isEmpty {
                                HStack {
                                    ProgressView()
                                        .padding()
                                    Text("読み込み中...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                            
                            // ── すべての記事を表示済み ──
                            if !viewModel.hasMore && !viewModel.articles.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                    Text("すべてを表示しました")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("3秒ニュース")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LastUpdatedLabel(date: viewModel.lastUpdated)
                }
            }
            .sheet(isPresented: $showSubscriptionSheet) {
                SubscriptionView(viewModel: viewModel)
            }
            .onReceive(SubscriptionManager.shared.$showSubscriptionPrompt) { shouldShow in
                if shouldShow {
                    let reason = SubscriptionManager.shared.promptReason
                    if reason == "limit" {
                        subscriptionPromptMessage = "本日の無料分析は終了しました"
                    } else if reason == "pro" {
                        subscriptionPromptMessage = "この機能はPro限定です"
                    }
                    showSubscriptionSheet = true
                    SubscriptionManager.shared.showSubscriptionPrompt = false
                }
            }
            // TabView 切换時に確実にデータを読み込む
            .onAppear {
                Task {
                    // 記事がない場合、または表示内容が空の場合は再読み込み
                    if viewModel.articles.isEmpty && !viewModel.isLoading {
                        await viewModel.loadInitialData()
                    }
                }
            }
        }
    }
    
    private func handleSubscriptionTrigger() {
        // サブスクリプションプロンプトが発火した場合の処理
        showSubscriptionSheet = true
    }
}

// MARK: - カテゴリチップ
struct CategoryChipsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 「すべて」チップ
                CategoryChip(
                    title: "すべて",
                    icon: "newspaper",
                    isSelected: viewModel.selectedCategory == nil
                ) {
                    viewModel.selectCategory(nil)
                }
                
                ForEach(NewsCategory.allCases, id: \.self) { cat in
                    CategoryChip(
                        title: cat.displayName,
                        icon: cat.icon,
                        isSelected: viewModel.selectedCategory == cat
                    ) {
                        viewModel.selectCategory(cat)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

struct CategoryChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(FontScaler.font(size: 12, weight: .medium))
                Text(title)
                    .font(FontScaler.font(size: 13, weight: .medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(isSelected ? Color.red : Color(.systemGray6))
            .foregroundColor(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
    }
}

// MARK: - トップストーリーセクション（横スクロール大カード）
struct TopStoriesSection: View {
    let articles: [NewsArticle]
    var onArticleTap: ((NewsArticle) -> Void)?
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "flame.fill")
                    .foregroundColor(.red)
                Text("トップストーリー")
                    .font(FontScaler.headline())
                    .fontWeight(.bold)
            }
            .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(articles) { article in
                        TopStoryCard(article: article)
                            .onTapGesture {
                                viewModel.markAsRead(article: article)
                                onArticleTap?(article)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }
}

struct TopStoryCard: View {
    let article: NewsArticle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // サムネイル
            Group {
                if let imageURL = article.validImageURL {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        CategoryPlaceholder(category: article.category, size: 60)
                    }
                } else {
                    CategoryPlaceholder(category: article.category, size: 60)
                }
            }
            .frame(width: 280, height: 160)
            .clipped()
            
            VStack(alignment: .leading, spacing: 6) {
                // カテゴリバッジ
                CategoryBadge(category: article.category)
                
                Text(article.title)
                    .font(FontScaler.font(size: 14, weight: .semibold))
                    .lineLimit(3)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(article.source.name)
                        .font(FontScaler.caption())
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(timeAgo(article.publishedAt))
                        .font(FontScaler.caption())
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .frame(width: 280)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
        .opacity(article.isRead ? 0.7 : 1.0)
    }
}

// MARK: - ニュース行（リスト）
struct NewsRowView: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: NewsViewModel
    
    @State private var showAnalysis = false
    @State private var showArticle = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── 記事情報 ──
            if let imageURL = article.validImageURL {
                // 有图片：两列布局
                HStack(alignment: .top, spacing: 10) {
                    // テキスト側
                    VStack(alignment: .leading, spacing: 4) {
                        // ソース + 時間
                        HStack(spacing: 4) {
                            Text(article.source.name)
                                .font(FontScaler.caption2(weight: .medium))
                                .foregroundColor(.red)
                                .lineLimit(1)
                            Text("·")
                                .foregroundColor(.secondary)
                                .font(FontScaler.caption2())
                            Text(timeAgo(article.publishedAt))
                                .font(FontScaler.caption2())
                                .foregroundColor(.secondary)
                            
                            if article.isBookmarked {
                                Image(systemName: "bookmark.fill")
                                    .font(FontScaler.font(size: 9))
                                    .foregroundColor(.orange)
                            }
                            Spacer()
                        }
                        
                        // タイトル
                        Text(article.title)
                            .font(FontScaler.font(size: 14, weight: article.isRead ? .regular : .semibold))
                            .lineLimit(3)
                            .foregroundColor(article.isRead ? .secondary : .primary)
                        
                        // サマリー
                        if !article.summary.isEmpty {
                            Text(article.summary)
                                .font(FontScaler.font(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    // サムネイル
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Color(.systemGray5)
                        default:
                            Color(.systemGray6)
                        }
                    }
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            } else {
                // 无图片：单列布局，文字占满宽度
                VStack(alignment: .leading, spacing: 4) {
                    // ソース + 時間 + Newsアイコン
                    HStack(spacing: 4) {
                        Text(article.source.name)
                            .font(FontScaler.caption2(weight: .medium))
                            .foregroundColor(.red)
                            .lineLimit(1)
                        Text("·")
                            .foregroundColor(.secondary)
                            .font(FontScaler.caption2())
                        Text(timeAgo(article.publishedAt))
                            .font(FontScaler.caption2())
                            .foregroundColor(.secondary)
                        
                        if article.isBookmarked {
                            Image(systemName: "bookmark.fill")
                                .font(FontScaler.font(size: 9))
                                .foregroundColor(.orange)
                        }
                        
                        Spacer()
                        
                        // 微妙的 news icon（无图片时显示）
                        Image(systemName: "newspaper")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .opacity(0.5)
                    }
                    
                    // タイトル
                    Text(article.title)
                        .font(FontScaler.font(size: 14, weight: article.isRead ? .regular : .semibold))
                        .lineLimit(3)
                        .foregroundColor(article.isRead ? .secondary : .primary)
                    
                    // サマリー（无图片时可显示更多）
                    if !article.summary.isEmpty {
                        Text(article.summary)
                            .font(FontScaler.font(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            }
            
            // ── アクションボタン ──
            HStack(spacing: 12) {
                Button(action: {
                    viewModel.markAsRead(article: article)
                    showAnalysis = true
                    Task {
                        let _ = await viewModel.analyzeArticle(article, deepAnalysis: false)
                    }
                }) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.caption)
                        Text("3秒で理解")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(6)
                }
                
                Button(action: {
                    viewModel.markAsRead(article: article)
                    showArticle = true
                }) {
                    HStack {
                        Image(systemName: "doc.text")
                            .font(.caption)
                        Text("原文を読む")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .background(Color(.systemBackground))
        
        // ── シート表示 ──
        .sheet(isPresented: $showAnalysis) {
            AIAnalysisView(article: article)
                .environmentObject(viewModel)
        }
        .sheet(isPresented: $showArticle) {
            ArticleWebView(article: article)
                .environmentObject(viewModel)
        }
    }
}

// MARK: - コンテキストメニュー
struct ArticleContextMenu: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        Group {
            Button {
                viewModel.toggleBookmark(article: article)
            } label: {
                Label(
                    article.isBookmarked ? "保存を解除" : "後で読む",
                    systemImage: article.isBookmarked ? "bookmark.slash" : "bookmark"
                )
            }
            
            Button {
                UIPasteboard.general.string = article.url.absoluteString
            } label: {
                Label("リンクをコピー", systemImage: "link")
            }
            
            Button {
                share(article: article)
            } label: {
                Label("共有", systemImage: "square.and.arrow.up")
            }
        }
    }
    
    private func share(article: NewsArticle) {
        let activityVC = UIActivityViewController(
            activityItems: [article.title, article.url],
            applicationActivities: nil
        )
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = scene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
}

// MARK: - カテゴリバッジ
struct CategoryBadge: View {
    let category: NewsCategory
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: category.icon)
                .font(FontScaler.font(size: 9))
            Text(category.displayName)
                .font(FontScaler.font(size: 10, weight: .medium))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.red.opacity(0.12))
        .foregroundColor(.red)
        .clipShape(Capsule())
    }
}

// MARK: - 最終更新ラベル
struct LastUpdatedLabel: View {
    let date: Date?
    
    var body: some View {
        if let date = date {
            Text(shortTime(date))
                .font(FontScaler.caption2())
                .foregroundColor(.secondary)
        }
    }
    
    private func shortTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "HH:mm 更新"
        return fmt.string(from: date)
    }
}

// MARK: - ローディングスケルトン
struct LoadingSkeletonView: View {
    @State private var animating = false
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                SkeletonRow()
                Divider().padding(.leading, 16)
            }
        }
        .onAppear { animating = true }
    }
}

struct SkeletonRow: View {
    @State private var opacity: Double = 0.4
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(width: 100, height: 10)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray4))
                    .frame(width: 200, height: 14)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray5))
                    .frame(height: 10)
            }
            Spacer()
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemGray4))
                .frame(width: 80, height: 80)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .opacity(opacity)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - 空状態
struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "newspaper")
                .font(FontScaler.font(size: 60))
                .foregroundColor(.gray.opacity(0.4))
            Text("記事がありません")
                .font(FontScaler.headline())
                .foregroundColor(.secondary)
            Text("後でもう一度お試しください")
                .font(FontScaler.subheadline())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - 時間フォーマット（グローバル関数）
func timeAgo(_ date: Date) -> String {
    let diff = Date().timeIntervalSince(date)
    if diff < 60 { return "たった今" }
    if diff < 3600 { return "\(Int(diff/60))分前" }
    if diff < 86400 { return "\(Int(diff/3600))時間前" }
    let fmt = DateFormatter()
    fmt.locale = Locale(identifier: "ja_JP")
    fmt.dateFormat = "M月d日"
    return fmt.string(from: date)
}

// MARK: - カテゴリ別プレースホルダー
struct CategoryPlaceholder: View {
    let category: NewsCategory
    var size: CGFloat = 28
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [category.color.opacity(0.6), category.color.opacity(0.3)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(FontScaler.font(size: size * 0.6, weight: .semibold))
                    .foregroundColor(.white)
                Text(category.displayName)
                    .font(FontScaler.font(size: size * 0.25, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
    }
}
