import SwiftUI
import GoogleMobileAds

// MARK: - ホーム画面
struct HomeView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var selectedArticle: NewsArticle? = nil
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // ── カテゴリチップ ──
                    CategoryChipsView()
                        .padding(.top, 8)
                    
                    if (viewModel.isLoading && viewModel.articles.isEmpty)
                        || (viewModel.isCategoryLoading && viewModel.filteredArticles.isEmpty) {
                        LoadingSkeletonView()
                    } else if viewModel.filteredArticles.isEmpty {
                        EmptyStateView()
                    } else {
                        if viewModel.selectedCategory == nil, !viewModel.todayEssentials.isEmpty {
                            TodayEssentialsSection(
                                articles: viewModel.todayEssentials,
                                onArticleTap: { article in
                                    viewModel.markAsRead(article: article)
                                    selectedArticle = article
                                }
                            )
                            .padding(.top, 12)
                        }

                        if viewModel.selectedCategory == nil, !viewModel.newsEvents.isEmpty {
                            MultiSourceEventsSection(
                                events: viewModel.newsEvents,
                                onArticleTap: { article in
                                    viewModel.markAsRead(article: article)
                                    selectedArticle = article
                                }
                            )
                            .padding(.top, 18)
                        }

                        // ── トップストーリー（大カード） ──
                        if viewModel.selectedCategory == nil, viewModel.topStories.count > 0 {
                            TopStoriesSection(
                                articles: viewModel.topStories,
                                onArticleTap: { article in
                                    selectedArticle = article
                                }
                            )
                                .padding(.top, 12)
                        }
                        
                        // ── ニュースリスト ──
                        LazyVStack(spacing: 0) {
                            if viewModel.isLoading || viewModel.isCategoryLoading {
                                InlineRefreshIndicator()
                            }

                            ForEach(Array(viewModel.filteredArticles.enumerated()), id: \.element.id) { index, article in
                                NewsRowView(article: article)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        viewModel.markAsRead(article: article)
                                        selectedArticle = article
                                    }
                                    .contextMenu {
                                        ArticleContextMenu(article: article)
                                    }
                                
                                Divider().padding(.leading, 16)

                                if AdPlacement.shouldShowInlineBanner(after: index) {
                                    InlineBannerAdRow()
                                }
                            }
                            
                            // ── 無限スクロール フッター ──
                            if viewModel.hasMore {
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
                                    Task { await viewModel.loadMore() }
                                }
                            } else if !viewModel.articles.isEmpty {
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
                        .padding(.top, 4)
                    }
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("ニュースNow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    LastUpdatedLabel(date: viewModel.lastUpdated)
                }
            }
            .sheet(item: $selectedArticle, onDismiss: {
                // 記事詳細を閉じた後、インタースティシャル広告を表示
                AdManager.shared.showInterstitial(from: InterstitialAdHelper.topViewController())
            }) { article in
                ArticleWebView(article: article)
            }
            // ── 左右スワイプ でカテゴリ切替 ──
            .gesture(
                DragGesture()
                    .onEnded { value in
                        handleSwipe(value)
                    }
            )
        }
    }
    
    /// スワイプ ジェスチャーを処理
    private func handleSwipe(_ gesture: DragGesture.Value) {
        let horizontalAmount = gesture.translation.width
        let threshold: CGFloat = 50  // 最小スワイプ距離
        
        guard abs(horizontalAmount) > threshold else { return }
        
        let categories = [nil] + NewsCategory.allCases  // nil は「すべて」を表す
        guard let currentIndex = categories.firstIndex(where: { $0 == viewModel.selectedCategory }) else { return }
        
        if horizontalAmount > 0 {
            // 右スワイプ → 前のカテゴリへ
            if currentIndex > 0 {
                viewModel.selectCategory(categories[currentIndex - 1])
            }
        } else {
            // 左スワイプ → 次のカテゴリへ
            if currentIndex < categories.count - 1 {
                viewModel.selectCategory(categories[currentIndex + 1])
            }
        }
    }
}

// MARK: - 今日の必読5件
private struct TodayEssentialsSection: View {
    let articles: [NewsArticle]
    let onArticleTap: (NewsArticle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("今日の5件", systemImage: "checklist")
                    .font(FontScaler.headline())
                    .fontWeight(.bold)
                Spacer()
                Text("これだけで流れがわかる")
                    .font(FontScaler.caption2())
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                    Button {
                        onArticleTap(article)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1)")
                                .font(FontScaler.font(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(article.category.color)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 3) {
                                Text(article.title)
                                    .font(FontScaler.font(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(2)
                                Text(article.instantInsight)
                                    .font(FontScaler.caption2())
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    if index < articles.count - 1 { Divider() }
                }
            }
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - 複数メディアで追うイベント
private struct MultiSourceEventsSection: View {
    let events: [NewsEvent]
    let onArticleTap: (NewsArticle) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("ひとつの出来事、多角的に", systemImage: "rectangle.3.group.bubble.left.fill")
                    .font(FontScaler.headline())
                    .fontWeight(.bold)
                Spacer()
                Text("重複を整理")
                    .font(FontScaler.caption2())
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(events.prefix(5)) { event in
                        Button { onArticleTap(event.headline) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(event.headline.title)
                                    .font(FontScaler.font(size: 14, weight: .semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                                Text(event.headline.instantInsight)
                                    .font(FontScaler.caption2())
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                                Spacer(minLength: 0)
                                HStack(spacing: 5) {
                                    Image(systemName: "newspaper.fill")
                                    Text("\(event.sourceCount)媒体の報道")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .font(FontScaler.caption2(weight: .medium))
                                .foregroundColor(.red)
                            }
                            .padding(14)
                            .frame(width: 250, height: 150, alignment: .topLeading)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private struct InlineRefreshIndicator: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
                .tint(.red)
            Text("更新中...")
                .font(FontScaler.caption())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
    }
}

// MARK: - カテゴリチップ
struct CategoryChipsView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
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
                    .id(0)  // ID: 0 for "すべて"
                    
                    ForEach(Array(NewsCategory.allCases.enumerated()), id: \.element) { index, cat in
                        CategoryChip(
                            title: cat.displayName,
                            icon: cat.icon,
                            isSelected: viewModel.selectedCategory == cat
                        ) {
                            viewModel.selectCategory(cat)
                        }
                        .id(index + 1)  // ID: 1+ for each category
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.selectedCategory) { newValue in
                withAnimation(.easeInOut(duration: 0.3)) {
                    let scrollID = newValue == nil ? 0 : (NewsCategory.allCases.firstIndex(of: newValue!) ?? 0) + 1
                    proxy.scrollTo(scrollID, anchor: .center)
                }
            }
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
        .animation(.easeInOut(duration: 0.15), value: isSelected)
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
    
    var body: some View {
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
            
            // サムネイル（有图片才显示）
            if let imageURL = article.validImageURL {
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
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
    private static let formatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "HH:mm 更新"
        return fmt
    }()
    
    var body: some View {
        if let date = date {
            Text(shortTime(date))
                .font(FontScaler.caption2())
                .foregroundColor(.secondary)
        }
    }
    
    private func shortTime(_ date: Date) -> String {
        Self.formatter.string(from: date)
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
    return SharedDateFormatters.monthDay.string(from: date)
}

private enum SharedDateFormatters {
    static let monthDay: DateFormatter = {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日"
        return fmt
    }()
}

// MARK: - カテゴリ別プレースホルダー
struct CategoryPlaceholder: View {
    let category: NewsCategory
    var size: CGFloat = 28

    var body: some View {
        ZStack {
            // 背景：分類別グラデーション
            LinearGradient(
                colors: [category.color.opacity(0.7), category.color.opacity(0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // 装飾パターン（分類別）
            DecorativePattern(category: category, size: size)

            // 中央アイコン + 分類名
            VStack(spacing: size > 40 ? 6 : 2) {
                Image(systemName: category.decorativeIcon)
                    .font(FontScaler.font(size: size * 0.5, weight: .semibold))
                    .foregroundColor(.white)
                if size > 35 {
                    Text(category.displayName)
                        .font(FontScaler.font(size: size * 0.22, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .tracking(1)
                }
            }
        }
    }
}

// MARK: - 分類別装飾パターン
struct DecorativePattern: View {
    let category: NewsCategory
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let patternColor = Color.white.opacity(0.08)
            switch category {
            case .general:
                // 新聞紙の行のような横線（確定的な幅パターン）
                let widths: [CGFloat] = [0.7, 0.5, 0.85, 0.4, 0.9, 0.6, 0.75, 0.55, 0.8, 0.45]
                var wi = 0
                for y in stride(from: 20, to: canvasSize.height, by: 12) {
                    let w = canvasSize.width * widths[wi % widths.count]
                    wi += 1
                    let rect = CGRect(x: 10, y: y, width: w, height: 3)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(patternColor))
                }
            case .celebrity:
                // キラキラ星散り（確定的な位置）
                let stars: [(CGFloat, CGFloat, CGFloat)] = [
                    (0.15, 0.2, 8), (0.7, 0.15, 6), (0.85, 0.4, 10),
                    (0.1, 0.65, 5), (0.5, 0.5, 7), (0.3, 0.8, 9),
                    (0.8, 0.75, 6), (0.6, 0.25, 8)
                ]
                for (px, py, s) in stars {
                    let star = starPath(center: CGPoint(x: canvasSize.width * px, y: canvasSize.height * py), size: s)
                    context.fill(star, with: .color(Color.white.opacity(0.12)))
                }
            case .politician:
                // 建物の柱のような縦線
                let cols = 5
                let spacing = canvasSize.width / CGFloat(cols + 1)
                for i in 1...cols {
                    let x = spacing * CGFloat(i)
                    let rect = CGRect(x: x - 2, y: 10, width: 4, height: canvasSize.height - 20)
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(patternColor))
                    // 柱の上部に三角屋根
                    let tri = Path { p in
                        p.move(to: CGPoint(x: x - 8, y: 10))
                        p.addLine(to: CGPoint(x: x, y: 0))
                        p.addLine(to: CGPoint(x: x + 8, y: 10))
                        p.closeSubpath()
                    }
                    context.fill(tri, with: .color(patternColor))
                }
            case .sports:
                // ボールの軌跡のような円弧
                for i in 0..<3 {
                    let r = canvasSize.width * 0.3 * CGFloat(i + 1)
                    let arc = Path { p in
                        p.addArc(center: CGPoint(x: canvasSize.width * 0.8, y: canvasSize.height * 0.7),
                                 radius: r, startAngle: .degrees(180), endAngle: .degrees(260), clockwise: false)
                    }
                    context.stroke(arc, with: .color(patternColor), lineWidth: 2)
                }
            case .business:
                // バーチャート風の棒
                let heights: [CGFloat] = [0.3, 0.55, 0.7, 0.45, 0.6]
                let barW = canvasSize.width / CGFloat(heights.count * 2)
                for (i, h) in heights.enumerated() {
                    let x = barW * CGFloat(i * 2 + 1)
                    let barH = canvasSize.height * h * 0.6
                    let rect = CGRect(x: x, y: canvasSize.height - barH - 15, width: barW, height: barH)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(patternColor))
                }
            case .overseas:
                // 世界地図の緯度線のような弧
                for i in 0..<4 {
                    let y = canvasSize.height * CGFloat(i + 1) / 5
                    let arc = Path { p in
                        p.move(to: CGPoint(x: 0, y: y))
                        p.addQuadCurve(to: CGPoint(x: canvasSize.width, y: y),
                                       control: CGPoint(x: canvasSize.width / 2, y: y - 15))
                    }
                    context.stroke(arc, with: .color(patternColor), lineWidth: 1.5)
                }
            case .trending:
                // 炎のような上向きの波形
                for i in 0..<5 {
                    let x = canvasSize.width * CGFloat(i) / 4
                    let wave = Path { p in
                        p.move(to: CGPoint(x: x, y: canvasSize.height))
                        p.addQuadCurve(to: CGPoint(x: x + canvasSize.width / 4, y: canvasSize.height * 0.2),
                                       control: CGPoint(x: x + canvasSize.width / 8, y: canvasSize.height * 0.4))
                    }
                    context.stroke(wave, with: .color(patternColor), lineWidth: 2)
                }
            }
        }
    }

    private func starPath(center: CGPoint, size: CGFloat) -> Path {
        var path = Path()
        for i in 0..<5 {
            let angle = .pi / 2 + .pi * 2 * Double(i) / 5
            let innerAngle = angle + .pi / 5
            let outer = CGPoint(x: center.x + size * CGFloat(cos(angle)), y: center.y - size * CGFloat(sin(angle)))
            let inner = CGPoint(x: center.x + size * 0.4 * CGFloat(cos(innerAngle)), y: center.y - size * 0.4 * CGFloat(sin(innerAngle)))
            if i == 0 { path.move(to: outer) } else { path.addLine(to: outer) }
            path.addLine(to: inner)
        }
        path.closeSubpath()
        return path
    }
}
