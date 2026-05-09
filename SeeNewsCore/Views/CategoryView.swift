import SwiftUI

// MARK: - カテゴリ一覧画面
struct CategoryView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var selectedCategory: NewsCategory = .trending
    @State private var categoryArticles: [NewsArticle] = []
    @State private var isLoadingCategory = false
    @State private var selectedArticle: NewsArticle? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // タブバー（カテゴリ）
                CategoryTabBar(selected: $selectedCategory)
                
                Divider()
                
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
                            ForEach(categoryArticles.dropFirst()) { article in
                                NewsRowView(article: article)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.markAsRead(article: article)
                                        selectedArticle = article
                                    }
                                Divider().padding(.leading, 16)
                            }
                        }
                    }
                }
            }
            .navigationTitle("カテゴリ")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: selectedCategory) { _ in
                loadCategory(selectedCategory)
            }
            .onAppear {
                loadCategory(selectedCategory)
            }
            .sheet(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
            // ── 左右滑动切换分类 ──
            .gesture(
                DragGesture(minimumDistance: 50)  // 最小滑动距离 50pt
                    .onEnded { gesture in
                        let categories = NewsCategory.allCases
                        guard let currentIndex = categories.firstIndex(of: selectedCategory) else { return }
                        
                        // 左滑（向左移动）→ 下一个分类
                        if gesture.translation.width < -50 {
                            let nextIndex = (currentIndex + 1) % categories.count
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedCategory = categories[nextIndex]
                            }
                        }
                        // 右滑（向右移动）→ 上一个分类
                        else if gesture.translation.width > 50 {
                            let previousIndex = (currentIndex - 1 + categories.count) % categories.count
                            withAnimation(.easeInOut(duration: 0.3)) {
                                selectedCategory = categories[previousIndex]
                            }
                        }
                    }
            )
        }
    }
    
    /// カテゴリ切替時にデータを読み込む
    private func loadCategory(_ category: NewsCategory) {
        isLoadingCategory = true
        Task {
            let results = await viewModel.loadCategoryArticles(category)
            await MainActor.run {
                categoryArticles = results
                isLoadingCategory = false
            }
        }
    }
}

// MARK: - カテゴリタブバー
struct CategoryTabBar: View {
    @Binding var selected: NewsCategory
    
    var body: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(NewsCategory.allCases, id: \.self) { cat in
                        CategoryTabItem(
                            category: cat,
                            isSelected: selected == cat
                        ) {
                            withAnimation(.easeInOut(duration: 0.3)) {  // ← 統一 0.3秒
                                selected = cat
                            }
                        }
                        .id(cat)
                    }
                }
                .padding(.horizontal, 8)
            }
            .onChange(of: selected) { newCategory in
                // 选中的 tab 滚动到左侧可见位置
                // 添加小延迟（0.05s）确保滑动完成后再触发滚动，避免冲突
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        reader.scrollTo(newCategory, anchor: .leading)
                    }
                }
            }
        }
        .frame(height: 48)
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
