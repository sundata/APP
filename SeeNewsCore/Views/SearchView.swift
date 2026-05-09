import SwiftUI

// MARK: - 検索画面
struct SearchView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @FocusState private var isSearchFocused: Bool
    @State private var selectedArticle: NewsArticle? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 検索バー
                SearchBar(text: $viewModel.searchQuery, isFocused: $isSearchFocused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                
                if viewModel.searchQuery.isEmpty {
                    TrendingTopicsView()
                } else if viewModel.searchResults.isEmpty {
                    NoResultsView(query: viewModel.searchQuery)
                } else {
                    // 結果リスト
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            // 件数ヘッダー
                            HStack {
                                Text("\(viewModel.searchResults.count)件の結果")
                                    .font(FontScaler.caption())
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            
                            ForEach(viewModel.searchResults) { article in
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
            .navigationTitle("検索")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
        }
    }
}

// MARK: - 検索バー
struct SearchBar: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("キーワードを入力...", text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - トレンドトピック（検索空き時）
struct TrendingTopicsView: View {
    let trending = [
        "芸能", "スポーツ", "政治",
        "経済", "海外", "アイドル",
        "俳優", "スキャンダル",
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // トレンドキーワード
                VStack(alignment: .leading, spacing: 12) {
                    Label("トレンドキーワード", systemImage: "chart.line.uptrend.xyaxis")
                        .font(FontScaler.headline())
                        .padding(.horizontal, 16)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(trending, id: \.self) { keyword in
                            TrendingKeywordChip(keyword: keyword)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                // カテゴリ別に閲覧
                VStack(alignment: .leading, spacing: 12) {
                    Text("カテゴリで探す")
                        .font(FontScaler.headline())
                        .padding(.horizontal, 16)
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(NewsCategory.allCases, id: \.self) { cat in
                            CategorySearchCard(category: cat)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.top, 16)
        }
    }
}

struct TrendingKeywordChip: View {
    let keyword: String
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        Button {
            viewModel.searchQuery = keyword
        } label: {
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(FontScaler.font(size: 12))
                    .foregroundColor(.secondary)
                Text(keyword)
                    .font(FontScaler.font(size: 13))
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

struct CategorySearchCard: View {
    let category: NewsCategory
    @EnvironmentObject var viewModel: NewsViewModel
    
    var categoryColor: Color {
        switch category {
        case .celebrity: return .pink
        case .politician: return .blue
        case .sports: return .green
        case .business: return .orange
        case .overseas: return .purple
        case .trending: return .red
        case .general: return .gray
        }
    }
    
    var body: some View {
        Button {
            // カテゴリで記事を検索
            Task { await viewModel.searchByCategory(category) }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: category.icon)
                    .font(FontScaler.font(size: 24))
                    .foregroundColor(categoryColor)
                Text(category.displayName)
                    .font(FontScaler.font(size: 13, weight: .medium))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(categoryColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - 結果なし
struct NoResultsView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(FontScaler.font(size: 50))
                .foregroundColor(.gray.opacity(0.3))
            Text("「\(query)」の結果なし")
                .font(FontScaler.headline())
                .foregroundColor(.secondary)
            Text("別のキーワードで検索してください")
                .font(FontScaler.subheadline())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }
}
