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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    let content: ShareCardContent

    @State private var format: Format = .story
    @State private var renderedImage: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: KoyomiTheme.Spacing.m) {
                Picker("形式", selection: $format) {
                    ForEach(Format.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                ShareCardCanvas(content: content, format: format)
                    .aspectRatio(format.aspectRatio, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: KoyomiTheme.Radius.card, style: .continuous))
                    .accessibilityIdentifier("share.preview")

                if let renderedImage {
                    ShareLink(
                        item: renderedImage,
                        preview: SharePreview("Koyomi", image: renderedImage)
                    ) {
                        Text("シェアする")
                            .font(KoyomiTheme.bodyFont.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: KoyomiTheme.minimumTapTarget)
                    }
                    .accessibilityIdentifier("share.link")
                }
                Spacer()
            }
            .padding(KoyomiTheme.Spacing.m)
            .navigationTitle("シェアカード")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .task(id: format) { await MainActor.run { render() } }
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(
            content: ShareCardCanvas(content: content, format: format)
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

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [KoyomiTheme.nightSky, KoyomiTheme.mistPurple, KoyomiTheme.color(hex: content.luckyColor.hex).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            StarField(opacity: 0.6)
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
                Text(content.disclaimer)
                    .font(.system(.caption2, design: .default))
                    .opacity(0.85)
            }
            .foregroundStyle(KoyomiTheme.moonBeige)
            .padding(format == .story ? KoyomiTheme.Spacing.xl : KoyomiTheme.Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
