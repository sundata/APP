import SwiftUI
import ShiftTechoCore

/// 画面の地色。派手な演出はせず、長時間見ても疲れない無地に近い背景にする。
struct ShiftTechoBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ShiftTechoTheme.background(colorScheme)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

/// 情報のまとまりを示すカード。
struct ShiftTechoCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ShiftTechoTheme.Spacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: ShiftTechoTheme.Radius.card, style: .continuous)
                    .fill(ShiftTechoTheme.cardFill(colorScheme))
            )
            .overlay(
                RoundedRectangle(cornerRadius: ShiftTechoTheme.Radius.card, style: .continuous)
                    .stroke(ShiftTechoTheme.cardStroke(colorScheme), lineWidth: 1)
            )
    }
}

/// シフト名のラベル。色だけでなく必ず文字を出す。
struct ShiftLabelChip: View {
    let definition: ShiftDefinition
    var compact = false

    var body: some View {
        Text(compact ? definition.shortLabel : definition.name)
            .font(compact ? ShiftTechoTheme.captionFont : ShiftTechoTheme.bodyFont)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 4 : ShiftTechoTheme.Spacing.s)
            .padding(.vertical, compact ? 2 : ShiftTechoTheme.Spacing.xs)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(ShiftTechoTheme.color(definition.color))
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
        HStack(spacing: ShiftTechoTheme.Spacing.s) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(ShiftTechoTheme.color(color))
                .frame(width: 16, height: 16)
                .overlay {
                    if isRest {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.white)
                    }
                }
            Text(name)
                .font(ShiftTechoTheme.captionFont)
        }
        .accessibilityElement(children: .combine)
    }
}

/// 主要ボタン。最小 44pt のタップ領域を確保する。
struct ShiftTechoPrimaryButton: View {
    let title: String
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ShiftTechoTheme.bodyFont.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: ShiftTechoTheme.minimumTapTarget)
                .background(
                    RoundedRectangle(cornerRadius: ShiftTechoTheme.Radius.small, style: .continuous)
                        .fill(isEnabled ? ShiftTechoTheme.accent : ShiftTechoTheme.accent.opacity(0.35))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

struct ShiftTechoSecondaryButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(ShiftTechoTheme.bodyFont)
                .frame(maxWidth: .infinity, minHeight: ShiftTechoTheme.minimumTapTarget)
        }
        .buttonStyle(.plain)
    }
}

/// 空状態の案内。次にすることを必ず書く。
struct ShiftTechoEmptyState: View {
    let symbol: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: ShiftTechoTheme.Spacing.s) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(ShiftTechoTheme.accent)
            Text(title)
                .font(ShiftTechoTheme.headlineFont)
            Text(message)
                .font(ShiftTechoTheme.bodyFont)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(ShiftTechoTheme.Spacing.l)
    }
}

/// 一時的に出る Undo バー。
struct UndoBar: View {
    let title: String
    let undo: () -> Void

    var body: some View {
        HStack(spacing: ShiftTechoTheme.Spacing.m) {
            Text(title)
                .font(ShiftTechoTheme.captionFont)
            Spacer(minLength: 0)
            Button("元に戻す", action: undo)
                .font(ShiftTechoTheme.captionFont.weight(.semibold))
                .frame(minHeight: ShiftTechoTheme.minimumTapTarget)
                .accessibilityIdentifier("undoButton")
        }
        .padding(.horizontal, ShiftTechoTheme.Spacing.m)
        .background(.thinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        .padding(.horizontal, ShiftTechoTheme.Spacing.m)
    }
}
