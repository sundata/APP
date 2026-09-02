import SwiftUI
import KoyomiCore

/// シェアカード。オフラインでも生成できるよう、描画のみで完結させる。
/// ニックネーム・位置・生年月日は含めない。
struct ShareCardView: View {
    enum Format: String, CaseIterable, Identifiable {
        case story
        case square

        var id: String { rawValue }
        var title: String { self == .story ? "ストーリーズ（9:16）" : "スクエア（1:1）" }
        var size: CGSize { self == .story ? CGSize(width: 1080, height: 1920) : CGSize(width: 1080, height: 1080) }
        var aspectRatio: CGFloat { size.width / size.height }
    }

    enum Style: String, CaseIterable, Identifiable {
        case nightSky
        case candy
        case rose
        case journal

        var id: String { rawValue }
        var title: String {
            switch self {
            case .nightSky: return "夜空"
            case .candy: return "キャンディ"
            case .rose: return "ローズ"
            case .journal: return "手帳"
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let content: ShareCardContent

    @State private var format: Format = .story
    @State private var style: Style = .candy
    @State private var renderedImage: Image?

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let horizontalPadding = KoyomiTheme.Spacing.m * 2
                let maximumPreviewWidth: CGFloat = format == .story ? 280 : 360
                let previewWidth = min(max(proxy.size.width - horizontalPadding, 0), maximumPreviewWidth)

                ScrollView {
                    VStack(spacing: KoyomiTheme.Spacing.m) {
                        Picker("形式", selection: $format) {
                            ForEach(Format.allCases) { format in
                                Text(format.title).tag(format)
                            }
                        }
                        .pickerStyle(.segmented)

                        Picker("デザイン", selection: $style) {
                            ForEach(Style.allCases) { style in
                                Text(style.title).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        ShareCardCanvas(content: content, format: format, style: style)
                            .frame(width: previewWidth, height: previewWidth / format.aspectRatio)
                            .clipShape(RoundedRectangle(cornerRadius: KoyomiTheme.Radius.card, style: .continuous))
                            .shadow(color: KoyomiTheme.mistPurple.opacity(0.18), radius: 16, y: 8)
                            .accessibilityIdentifier("share.preview")

                        if let renderedImage {
                            ShareLink(
                                item: renderedImage,
                                subject: Text("今日のKoyomiをシェア"),
                                message: Text("今日の気分と小さな一歩、見せ合わない？ ✨ #Koyomi"),
                                preview: SharePreview("Koyomi", image: renderedImage)
                            ) {
                                Text("シェアする")
                                    .font(KoyomiTheme.bodyFont.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: KoyomiTheme.minimumTapTarget)
                            }
                            .accessibilityIdentifier("share.link")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(KoyomiTheme.Spacing.m)
                }
            }
            .navigationTitle("シェアカード")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task(id: "\(format.rawValue)-\(style.rawValue)") { await MainActor.run { render() } }
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(
            content: ShareCardCanvas(content: content, format: format, style: style)
                .frame(width: format.size.width / 2, height: format.size.height / 2)
        )
        renderer.scale = max(displayScale, 2)
        #if canImport(UIKit)
        if let uiImage = renderer.uiImage {
            renderedImage = Image(uiImage: uiImage)
        }
        #endif
    }
}

/// カードの描画内容。プレビューと書き出しで同じ View を使う。
struct ShareCardCanvas: View {
    let content: ShareCardContent
    let format: ShareCardView.Format
    let style: ShareCardView.Style

    var body: some View {
        ZStack {
            background
            if style != .journal { StarField(opacity: style == .nightSky ? 0.6 : 0.3) }
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.m) {
                Spacer(minLength: 0)
                Text(content.dateText)
                    .font(.system(.callout, design: .default))
                Text(content.zodiacName)
                    .font(.system(.caption, design: .default))
                Text(content.headline)
                    .font(.system(.title, design: .serif).weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text(content.shortMessage)
                    .font(.system(.body, design: .default))
                    .fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.xs) {
                    Text("LOVE KEYWORD")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .tracking(1.2)
                    Text(content.loveKeyword)
                        .font(.system(.title3, design: .serif).weight(.semibold))
                    Text(content.styleTip)
                        .font(.system(.footnote, design: .default))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(KoyomiTheme.Spacing.s)
                .background(Color.white.opacity(style == .journal ? 0.5 : 0.12), in: RoundedRectangle(cornerRadius: 14))
                HStack(spacing: KoyomiTheme.Spacing.s) {
                    Circle()
                        .fill(KoyomiTheme.color(hex: content.luckyColor.hex))
                        .frame(width: 16, height: 16)
                    Text(content.luckyColor.name)
                        .font(.system(.footnote, design: .default))
                }
                Spacer(minLength: 0)
                Text(content.brandName)
                    .font(.system(.headline, design: .serif))
                Text("友だちと今日の気分や小さな一歩を見せ合おう ✦")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                Text(content.disclaimer)
                    .font(.system(.caption2, design: .default))
                    .opacity(0.85)
            }
            .foregroundStyle(foregroundColor)
            .padding(format == .story ? KoyomiTheme.Spacing.xl : KoyomiTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .nightSky:
            LinearGradient(
                colors: [KoyomiTheme.nightSky, KoyomiTheme.mistPurple, KoyomiTheme.color(hex: content.luckyColor.hex).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .candy:
            LinearGradient(
                colors: [KoyomiTheme.lavenderMilk, KoyomiTheme.peachCream, KoyomiTheme.strawberryMilk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .rose:
            LinearGradient(
                colors: [Color(red: 0.34, green: 0.16, blue: 0.28), Color(red: 0.78, green: 0.48, blue: 0.57), Color(red: 0.96, green: 0.78, blue: 0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .journal:
            LinearGradient(
                colors: [Color(red: 0.99, green: 0.96, blue: 0.90), Color(red: 0.94, green: 0.88, blue: 0.82)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private var foregroundColor: Color {
        (style == .journal || style == .candy) ? KoyomiTheme.berryInk : KoyomiTheme.moonBeige
    }
}
