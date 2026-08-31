import SwiftUI

/// 夜空のグラデーションと、ゆっくり呼吸する星。
/// 「視差効果を減らす」設定のときはアニメーションしない。
struct NightSkyBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var breathing = false

    private var gradient: LinearGradient {
        let colors: [Color] = colorScheme == .dark
            ? [KoyomiTheme.deepIndigo, KoyomiTheme.nightSky, KoyomiTheme.mistPurple.opacity(0.35)]
            : [KoyomiTheme.lavenderMilk, KoyomiTheme.peachCream, KoyomiTheme.vanilla]
        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        ZStack {
            gradient
            if colorScheme == .light {
                Circle()
                    .fill(KoyomiTheme.strawberryMilk.opacity(0.28))
                    .frame(width: 260, height: 260)
                    .blur(radius: 8)
                    .offset(x: -150, y: -260)
                Circle()
                    .fill(KoyomiTheme.lavenderMilk.opacity(0.55))
                    .frame(width: 220, height: 220)
                    .blur(radius: 10)
                    .offset(x: 160, y: 210)
            }
            StarField(opacity: colorScheme == .dark ? (breathing ? 0.85 : 0.5) : (breathing ? 0.48 : 0.28))
                .blendMode(.screen)
        }
        .ignoresSafeArea()
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 6).repeatForever(autoreverses: true)) {
                breathing = true
            }
        }
        .accessibilityHidden(true)
    }
}

/// 決まった位置に星を描く（毎回ランダムに変わらないようにする）。
struct StarField: View {
    let opacity: Double

    private static let positions: [(x: Double, y: Double, size: Double)] = {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> Double {
            seed ^= seed << 13
            seed ^= seed >> 7
            seed ^= seed << 17
            return Double(seed % 10_000) / 10_000
        }
        return (0..<60).map { _ in (next(), next(), 1 + next() * 1.8) }
    }()

    var body: some View {
        GeometryReader { proxy in
            ForEach(Array(Self.positions.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(Color.white)
                    .frame(width: star.size, height: star.size)
                    .position(x: star.x * proxy.size.width, y: star.y * proxy.size.height * 0.8)
            }
        }
        .opacity(opacity)
    }
}

/// ガラス感のあるカード。
struct GlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(KoyomiTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: KoyomiTheme.Radius.card, style: .continuous)
                    .fill(KoyomiTheme.cardFill(colorScheme))
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: KoyomiTheme.Radius.card, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: KoyomiTheme.Radius.card, style: .continuous)
                    .stroke(KoyomiTheme.cardStroke(colorScheme), lineWidth: 1)
            )
            .shadow(color: colorScheme == .dark ? .clear : KoyomiTheme.strawberryMilk.opacity(0.14), radius: 14, y: 7)
    }
}

/// 星による点数表示。色だけに頼らず、数値も読み上げる。
struct ScoreStars: View {
    let score: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= score ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(index <= score ? KoyomiTheme.strawberryMilk : Color.secondary.opacity(0.35))
            }
            Text("\(score)/5")
                .font(KoyomiTheme.captionFont)
                .foregroundStyle(.secondary)
                .padding(.leading, KoyomiTheme.Spacing.xs)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(DailyFortuneAccessibility.scoreText(score)))
    }
}

enum DailyFortuneAccessibility {
    /// VoiceOver では「5段階中4」と読み上げる。
    static func scoreText(_ score: Int) -> String {
        "5段階中\(score)"
    }
}

/// 主要ボタン。最小 44pt のタップ領域を確保する。
struct KoyomiPrimaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KoyomiTheme.bodyFont.weight(.semibold))
                .foregroundStyle(KoyomiTheme.moonBeige)
                .frame(maxWidth: .infinity, minHeight: KoyomiTheme.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: KoyomiTheme.Radius.small, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [KoyomiTheme.strawberryMilk, KoyomiTheme.mistPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: KoyomiTheme.strawberryMilk.opacity(0.28), radius: 10, y: 5)
        }
        .buttonStyle(.plain)
    }
}

struct KoyomiSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KoyomiTheme.bodyFont)
                .frame(maxWidth: .infinity, minHeight: KoyomiTheme.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }
}

/// 読み込み中のスケルトン。
struct SkeletonCard: View {
    var lines: Int = 3

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: KoyomiTheme.Spacing.s) {
                ForEach(0..<lines, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 14)
                        .frame(maxWidth: index == lines - 1 ? 180 : .infinity)
                }
            }
        }
        .accessibilityLabel(Text("読み込み中"))
    }
}
