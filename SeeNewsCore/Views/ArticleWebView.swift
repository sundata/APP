import SwiftUI
import WebKit
import SafariServices

// MARK: - 記事WebView（元サイトへジャンプ）
struct ArticleWebView: View {
    let article: NewsArticle
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var isLoading = true
    @State private var progress: Double = 0
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var showShareSheet = false
    @State private var webViewRef: WKWebView? = nil
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // プログレスバー
                if isLoading {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.red)
                        .frame(height: 2)
                }
                
                // WebView 本体
                WebViewRepresentable(
                    url: article.url,
                    isLoading: $isLoading,
                    progress: $progress,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    webViewRef: $webViewRef
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左：閉じる
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(FontScaler.font(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                // 中央：ソース名
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text(article.source.name)
                            .font(FontScaler.caption(weight: .semibold))
                            .foregroundColor(.primary)
                        Text(article.url.host ?? "")
                            .font(FontScaler.font(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                // 右：アクション群
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.toggleBookmark(article: article)
                    } label: {
                        Image(systemName: article.isBookmarked ? "bookmark.fill" : "bookmark")
                            .foregroundColor(article.isBookmarked ? .orange : .primary)
                    }
                    
                    Button {
                        showShareSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.primary)
                    }
                    
                    // Safari で開く
                    Button {
                        UIApplication.shared.open(article.url)
                    } label: {
                        Image(systemName: "safari")
                            .foregroundColor(.primary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                // 下部ナビゲーションバー
                BottomNavBar(
                    canGoBack: canGoBack,
                    canGoForward: canGoForward,
                    onBack: { webViewRef?.goBack() },
                    onForward: { webViewRef?.goForward() },
                    onRefresh: { webViewRef?.reload() },
                    onSafari: { UIApplication.shared.open(article.url) }
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [article.title, article.url])
        }
    }
}

// MARK: - WebView ラッパー
struct WebViewRepresentable: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var webViewRef: WKWebView?
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        
        // プログレス監視
        context.coordinator.progressObservation = webView.observe(\.estimatedProgress) { wv, _ in
            DispatchQueue.main.async {
                self.progress = wv.estimatedProgress
            }
        }
        context.coordinator.canGoBackObservation = webView.observe(\.canGoBack) { wv, _ in
            DispatchQueue.main.async { self.canGoBack = wv.canGoBack }
        }
        context.coordinator.canGoForwardObservation = webView.observe(\.canGoForward) { wv, _ in
            DispatchQueue.main.async { self.canGoForward = wv.canGoForward }
        }
        
        DispatchQueue.main.async { self.webViewRef = webView }
        webView.load(URLRequest(url: url))
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {}
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable
        var progressObservation: NSKeyValueObservation?
        var canGoBackObservation: NSKeyValueObservation?
        var canGoForwardObservation: NSKeyValueObservation?
        
        init(_ parent: WebViewRepresentable) { self.parent = parent }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async { self.parent.isLoading = true }
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                self.parent.canGoBack = webView.canGoBack
                self.parent.canGoForward = webView.canGoForward
            }
        }
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async { self.parent.isLoading = false }
        }
    }
}

// MARK: - 下部ナビバー
struct BottomNavBar: View {
    let canGoBack: Bool
    let canGoForward: Bool
    let onBack: () -> Void
    let onForward: () -> Void
    let onRefresh: () -> Void
    let onSafari: () -> Void
    
    var body: some View {
        HStack {
            Spacer()
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(FontScaler.font(size: 18, weight: .medium))
                    .foregroundColor(canGoBack ? .primary : .gray.opacity(0.4))
            }
            .disabled(!canGoBack)
            Spacer()
            Button(action: onForward) {
                Image(systemName: "chevron.right")
                    .font(FontScaler.font(size: 18, weight: .medium))
                    .foregroundColor(canGoForward ? .primary : .gray.opacity(0.4))
            }
            .disabled(!canGoForward)
            Spacer()
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(FontScaler.font(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
            Spacer()
            Button(action: onSafari) {
                Image(systemName: "safari")
                    .font(FontScaler.font(size: 18, weight: .medium))
                    .foregroundColor(.primary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(Divider(), alignment: .top)
    }
}

// MARK: - シェアシート
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
