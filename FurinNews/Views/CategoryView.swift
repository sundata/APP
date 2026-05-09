import SwiftUI

// MARK: - カテゴリ一覧画面
struct CategoryView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var selectedCategory: NewsCategory = .trending
    @State private var categoryArticles: [NewsArticle] = []
    @State private var isLoadingCategory = false
    @State private var isLoadingMore = false
    @State private var hasMoreArticles = true
    @State private var selectedArticle: NewsArticle? = nil
    @State private var categoryPage = 1
    
    var body: some View {
        NavigationStack {
            TabView(selection: $selectedCategory) {
                ForEach(NewsCategory.allCases, id: \.self) { category in
                    categoryContentView(for: category)
                        .tag(category)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle("カテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
        }
    }
    
    /// カテゴリ別のコンテンツView
    @ViewBuilder
    private func categoryContentView(for category: NewsCategory) -> some View {
        VStack(spacing: 0) {
            if isLoadingCategory && categoryArticles.isEmpty {
                LoadingSkeletonView()
            } else if categoryArticles.isEmpty {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // 最新ピックアップ（大カード）
                        if let first = categoryArticles.first {
                            FeaturedArticleCard(article: first)
                                .padding(16)
                                .onTapGesture {
                                    viewModel.markAsRead(article: first)
                                    selectedArticle = first
                                }
                        }
                        
                        // 残りのリスト
                        ForEach(Array(categoryArticles.dropFirst().enumerated()), id: \.element.id) { index, article in
                            NewsRowView(article: article)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.markAsRead(article: article)
                                    selectedArticle = article
                                }
                            Divider().padding(.leading, 16)

                            if AdPlacement.shouldShowInlineBanner(after: index) {
                                InlineBannerAdRow()
                            }
                        }
                        
                        // ── 無限スクロール フッター ──
                        if hasMoreArticles {
                            // 読み込み中
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(.red)
                                Text("読み込み中...")
                                    .font(FontScaler.caption())
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .onAppear {
                                if !isLoadingMore {
                                    loadMoreInCategory()
                                }
                            }
                        } else if !categoryArticles.isEmpty {
                            // すべて表示完了
                            VStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                Text("すべてを表示しました")
                                    .font(FontScaler.font(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedCategory) { newCategory in
            if newCategory == category {
                loadCategory(category)
            }
        }
        .onAppear {
            if selectedCategory == category {
                loadCategory(category)
            }
        }
    }
    
    /// カテゴリ切替時にデータを読み込む
    private func loadCategory(_ category: NewsCategory) {
        isLoadingCategory = true
        isLoadingMore = false
        categoryPage = 1
        hasMoreArticles = true
        
        Task {
            let results = await viewModel.loadCategoryArticles(category, page: categoryPage)
            await MainActor.run {
                categoryArticles = results
                isLoadingCategory = false
                // APIから返されるデータでhasMoreを判定
                hasMoreArticles = results.count >= NewsService.pageSize
            }
        }
    }
    
    /// 無限スクロール用：追加記事を読み込む
    private func loadMoreInCategory() {
        guard !isLoadingMore && hasMoreArticles else { return }
        
        isLoadingMore = true
        categoryPage += 1
        
        Task {
            let results = await viewModel.loadCategoryArticles(selectedCategory, page: categoryPage)
            await MainActor.run {
                // 重複排除
                let existingIds = Set(categoryArticles.map { $0.id })
                let uniqueNew = results.filter { !existingIds.contains($0.id) }
                
                categoryArticles.append(contentsOf: uniqueNew)
                isLoadingMore = false
                
                // 返されたデータが少ない場合は、すべて読み込んだと判定
                hasMoreArticles = results.count >= NewsService.pageSize && !uniqueNew.isEmpty
            }
        }
    }
}

// MARK: - カテゴリタブバー
struct CategoryTabBar: View {
    @Binding var selected: NewsCategory
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(NewsCategory.allCases, id: \.self) { cat in
                        CategoryTabItem(
                            category: cat,
                            isSelected: selected == cat
                        ) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selected = cat
                            }
                        }
                        .id(cat)
                    }
                }
                .padding(.horizontal, 8)
            }
            .frame(height: 48)
            .onChange(of: selected) { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
        }
    }
}

struct CategoryTabItem: View {
    let category: NewsCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: category.icon)
                        .font(FontScaler.font(size: 13))
                    Text(category.displayName)
                        .font(FontScaler.font(size: 13, weight: isSelected ? .bold : .regular))
                }
                .foregroundColor(isSelected ? .red : .secondary)
                .padding(.horizontal, 14)
                .padding(.top, 10)
                
                // インジケーター
                Rectangle()
                    .fill(isSelected ? Color.red : Color.clear)
                    .frame(height: 2)
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - フィーチャー記事カード（大）
struct FeaturedArticleCard: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // サムネイル
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let imageURL = article.validImageURL {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            CategoryPlaceholder(category: article.category, size: 50)
                        }
                    } else {
                        CategoryPlaceholder(category: article.category, size: 50)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                
                // グラデーションオーバーレイ
                LinearGradient(
                    colors: [.clear, .black.opacity(0.6)],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 200)
                
                // カテゴリバッジ
                CategoryBadge(category: article.category)
                    .padding(12)
            }
            
            // テキスト
            VStack(alignment: .leading, spacing: 8) {
                Text(article.title)
                    .font(FontScaler.font(size: 17, weight: .bold))
                    .lineLimit(3)
                
                Text(article.summary)
                    .font(FontScaler.subheadline())
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                
                HStack {
                    Text(article.source.name)
                        .font(FontScaler.caption(weight: .medium))
                        .foregroundColor(.red)
                    Text("·")
                        .foregroundColor(.secondary)
                    Text(timeAgo(article.publishedAt))
                        .font(FontScaler.caption())
                        .foregroundColor(.secondary)
                    Spacer()
                    Button {
                        viewModel.toggleBookmark(article: article)
                    } label: {
                        Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(article.isBookmarked ? .orange : .secondary)
                    }
                }
            }
            .padding(14)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)
    }
}
