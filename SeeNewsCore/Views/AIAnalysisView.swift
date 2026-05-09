import SwiftUI

// MARK: - AI分析結果表示ビュー
struct AIAnalysisView: View {
    let article: NewsArticle
    
    @EnvironmentObject var viewModel: NewsViewModel
    @Environment(\.dismiss) var dismiss
    
    // ✅ 使用 @ObservedObject 订阅 shared 单例（不创建新实例）
    @ObservedObject var aiService = AIAnalysisService.shared
    
    @State private var showDeepAnalysis = false
    @State private var isRefreshing = false
    @State private var elapsedSeconds = 0  // ✅ 追踪分析时间
    @State private var timer: Timer?
    
    // ✅ 根据 article ID 获取该文章的分析
    var analysis: AIAnalysis? {
        aiService.analyses[article.id]
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if let analysis = analysis {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            // ── 記事タイトル ──
                            VStack(alignment: .leading, spacing: 8) {
                                Text(article.title)
                                    .font(.headline)
                                    .lineLimit(3)
                                
                                HStack(spacing: 8) {
                                    Text(article.source.name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Text(viewModel.formattedDate(article.publishedAt))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            
                            // ── 一言まとめ ──
                            VStack(alignment: .leading, spacing: 8) {
                                Label("一言まとめ", systemImage: "sparkles")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text(analysis.summary)
                                    .font(.body)
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // ── 3つのポイント ──
                            VStack(alignment: .leading, spacing: 12) {
                                Label("3つのポイント", systemImage: "list.number")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                ForEach(Array(analysis.keyPoints.enumerated()), id: \.offset) { index, point in
                                    HStack(alignment: .top, spacing: 12) {
                                        Text("\(index + 1)")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .frame(width: 30, height: 30)
                                            .background(Color.green)
                                            .cornerRadius(15)
                                        
                                        Text(point)
                                            .font(.body)
                                            .lineLimit(3)
                                        
                                        Spacer()
                                    }
                                }
                            }
                            
                            // ── なぜ重要か ──
                            VStack(alignment: .leading, spacing: 8) {
                                Label("なぜ重要か", systemImage: "exclamationmark.circle")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                                
                                Text(analysis.importance)
                                    .font(.body)
                                    .padding()
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            // ── Pro限定：深度分析 ──
                            if viewModel.userSubscription.isPro || analysis.deepAnalysis != nil {
                                DeepAnalysisSection(analysis: analysis, isExpanded: $showDeepAnalysis)
                            } else {
                                // Pro限定プロモーション
                                ProPromotionCard(viewModel: viewModel)
                            }
                            
                            Spacer(minLength: 20)
                        }
                        .padding()
                    }
                } else {
                    // 分析中のローディング画面
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("AI分析中...")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        if let error = aiService.error {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        
                        // ✅ 显示分析时间（超过30秒显示重试选项）
                        if elapsedSeconds > 0 {
                            Text("(\(elapsedSeconds)秒)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        if elapsedSeconds > 30 {
                            VStack(spacing: 12) {
                                Text("分析に時間がかかっています")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        dismiss()
                                    }) {
                                        Text("キャンセル")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.3))
                                            .cornerRadius(6)
                                    }
                                    
                                    Button(action: {
                                        elapsedSeconds = 0
                                        Task {
                                            let _ = await viewModel.analyzeArticle(article, deepAnalysis: false)
                                        }
                                    }) {
                                        Text("リトライ")
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(Color.blue)
                                            .foregroundColor(.white)
                                            .cornerRadius(6)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                    .onAppear {
                        elapsedSeconds = 0
                        startTimer()
                    }
                    .onDisappear {
                        stopTimer()
                    }
                }
            }
            
            .navigationTitle("3秒で理解")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    if analysis != nil {
                        Button(action: {
                            UIPasteboard.general.string = formatAnalysisForSharing()
                        }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if isRefreshing {
                        ProgressView()
                    } else {
                        Button(action: {
                            Task {
                                isRefreshing = true
                                // ✅ 直接调用 aiService 刷新，它会自动更新 analyses[article.id]
                                _ = await aiService.refreshAnalysis(
                                    article,
                                    includeDeepAnalysis: viewModel.userSubscription.isPro,
                                    userPlan: viewModel.userSubscription.plan
                                )
                                // ✅ analysis computed property 会自动读取更新后的值
                                isRefreshing = false
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(isRefreshing)
                    }
                }
            }
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            elapsedSeconds += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func formatAnalysisForSharing() -> String {
        guard let analysis = analysis else { return "AI分析中..." }
        
        var text = "📰 \(article.title)\n\n"
        text += "✨ 一言まとめ\n\(analysis.summary)\n\n"
        text += "📍 3つのポイント\n"
        for (i, point) in analysis.keyPoints.enumerated() {
            text += "\(i + 1). \(point)\n"
        }
        text += "\n⚠️ なぜ重要か\n\(analysis.importance)"
        return text
    }
}

// MARK: - Pro限定：深度分析セクション
struct DeepAnalysisSection: View {
    let analysis: AIAnalysis
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Label("深度分析 (Pro限定)", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)
                        .foregroundColor(.purple)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.purple)
                }
                .contentShape(Rectangle())
            }
            
            if isExpanded, let deepAnalysis = analysis.deepAnalysis {
                VStack(alignment: .leading, spacing: 12) {
                    // 影響分析
                    VStack(alignment: .leading, spacing: 6) {
                        Label("影響分析", systemImage: "globe")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Text(deepAnalysis.impactAnalysis)
                            .font(.caption)
                            .lineLimit(4)
                            .padding(8)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // 今後の予測
                    VStack(alignment: .leading, spacing: 6) {
                        Label("今後の予測", systemImage: "sparkles")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Text(deepAnalysis.futurePredict)
                            .font(.caption)
                            .lineLimit(4)
                            .padding(8)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(6)
                    }
                    
                    Divider()
                    
                    // 行動提案
                    VStack(alignment: .leading, spacing: 6) {
                        Label("行動アドバイス", systemImage: "lightbulb.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                        
                        Text(deepAnalysis.actionAdvice)
                            .font(.caption)
                            .lineLimit(4)
                            .padding(8)
                            .background(Color.purple.opacity(0.08))
                            .cornerRadius(6)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Pro限定プロモーションカード
struct ProPromotionCard: View {
    let viewModel: NewsViewModel
    @State private var showSubscriptionView = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "crown.fill")
                    .foregroundColor(.yellow)
                    .font(.title3)
                
                Text("Pro限定")
                    .font(.headline)
                    .foregroundColor(.yellow)
            }
            
            Text("深度分析にアクセスするには Proプランへのアップグレードが必要です")
                .font(.body)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 6) {
                Label("影響分析", systemImage: "globe")
                    .font(.caption)
                Label("今後の予測", systemImage: "sparkles")
                    .font(.caption)
                Label("行動アドバイス", systemImage: "lightbulb.fill")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            
            Button(action: {
                // Pro限定機能クリック時のトリガー
                SubscriptionManager.shared.promptReason = "pro"
                SubscriptionManager.shared.showSubscriptionPrompt = true
                showSubscriptionView = true
            }) {
                Text("Proプランを試す")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
        .sheet(isPresented: $showSubscriptionView) {
            SubscriptionView(viewModel: viewModel)
        }
    }
}
