import SwiftUI

// MARK: - ブックマーク画面
struct BookmarkView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var editMode: EditMode = .inactive
    @State private var selectedArticle: NewsArticle? = nil
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.bookmarkedArticles.isEmpty {
                    BookmarkEmptyView()
                } else {
                    List {
                        ForEach(viewModel.bookmarkedArticles) { article in
                            BookmarkRow(article: article)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    viewModel.markAsRead(article: article)
                                    selectedArticle = article
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let article = viewModel.bookmarkedArticles[index]
                                viewModel.toggleBookmark(article: article)
                            }
                        }
                    }
                    .listStyle(.plain)
                    .environment(\.editMode, $editMode)
                }
            }
            .navigationTitle("保存済み")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !viewModel.bookmarkedArticles.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(editMode == .active ? "完了" : "編集") {
                            editMode = editMode == .active ? .inactive : .active
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .sheet(item: $selectedArticle) { article in
                ArticleWebView(article: article)
            }
        }
    }
}// MARK: - ブックマーク行
struct BookmarkRow: View {
    let article: NewsArticle
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                // サムネイル
                Group {
                    if let imageURL = article.validImageURL {
                        AsyncImage(url: imageURL) { image in
                            image.resizable().aspectRatio(contentMode: .fill)
                        } placeholder: {
                            CategoryPlaceholder(category: article.category, size: 30)
                        }
                    } else {
                        CategoryPlaceholder(category: article.category, size: 30)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 5) {
                    // カテゴリ + ソース
                    HStack(spacing: 6) {
                        CategoryBadge(category: article.category)
                        Text(article.source.name)
                            .font(FontScaler.caption())
                            .foregroundColor(.secondary)
                    }
                    
                    Text(article.title)
                        .font(FontScaler.font(size: 14, weight: .semibold))
                        .lineLimit(3)
                    
                    HStack {
                        Text(timeAgo(article.publishedAt))
                            .font(FontScaler.caption2())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button {
                            viewModel.toggleBookmark(article: article)
                        } label: {
                            Image(systemName: "bookmark.fill")
                                .foregroundColor(.orange)
                                .font(FontScaler.font(size: 14))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(16)
            
            Divider().padding(.leading, 118)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - 空のブックマーク
struct BookmarkEmptyView: View {
    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "bookmark")
                    .font(FontScaler.font(size: 44, weight: .light))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("保存済みがありません")
                    .font(FontScaler.title3(weight: .semibold))
                Text("気になる記事を見つけたら\nブックマークアイコンをタップ")
                    .font(FontScaler.subheadline())
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
