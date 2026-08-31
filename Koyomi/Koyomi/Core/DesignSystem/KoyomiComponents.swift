import SwiftUI
import KoyomiCore

/// 画面の地色。派手な演出はせず、長時間見ても疲れない無地に近い背景にする。
struct KoyomiBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        KoyomiTheme.background(colorScheme)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// 情報のまとまりを示すカード。
struct KoyomiCard<Content: View>: View {
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
            )
            .overlay(
                RoundedRectangle(cornerRadius: KoyomiTheme.Radius.card, style: .continuous)
                    .stroke(KoyomiTheme.cardStroke(colorScheme), lineWidth: 1)
            )
    }
}

/// シフト名のラベル。色だけでなく必ず文字を出す。
struct ShiftLabelChip: View {
    let definition: ShiftDefinition
    var compact = false

    var body: some View {
        Text(compact ? definition.shortLabel : definition.name)
            .font(compact ? KoyomiTheme.captionFont : KoyomiTheme.bodyFont)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : KoyomiTheme.Spacing.s)
            .padding(.vertical, compact ? 2 : KoyomiTheme.Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(KoyomiTheme.color(definition.color))
            )
            .accessibilityHidden(true)
    }
}

/// 色の凡例。四角＋名前をセットで並べる。
struct ShiftLegendRow: View {
    let name: String
    let color: ShiftColor
    let isRest: Bool

    var body: some View {
        HStack(spacing: KoyomiTheme.Spacing.s) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(KoyomiTheme.color(color))
                .frame(width: 16, height: 16)
                .overlay {
                    if isRest {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                    }
                }
            Text(name)
                .font(KoyomiTheme.captionFont)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 主要ボタン。最小 44pt のタップ領域を確保する。
struct KoyomiPrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(KoyomiTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: KoyomiTheme.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: KoyomiTheme.Radius.small, style: .continuous)
                        .fill(isEnabled ? KoyomiTheme.accent : KoyomiTheme.accent.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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

/// 空状態の案内。次にすることを必ず書く。
struct KoyomiEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: KoyomiTheme.Spacing.s) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(KoyomiTheme.accent)
            Text(title)
                .font(KoyomiTheme.headlineFont)
            Text(message)
                .font(KoyomiTheme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(KoyomiTheme.Spacing.l)
    }
}

/// 一時的に出る Undo バー。
struct UndoBar: View {
    let title: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: KoyomiTheme.Spacing.m) {
            Text(title)
                .font(KoyomiTheme.captionFont)
            Spacer(minLength: 0)
            Button("元に戻す", action: undo)
                .font(KoyomiTheme.captionFont.weight(.semibold))
                .frame(minHeight: KoyomiTheme.minimumTapTarget)
                .accessibilityIdentifier("undoButton")
        }
        .padding(.horizontal, KoyomiTheme.Spacing.m)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, KoyomiTheme.Spacing.m)
    }
}
