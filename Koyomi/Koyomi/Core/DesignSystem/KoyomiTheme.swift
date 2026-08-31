import SwiftUI
import KoyomiCore

/// 色・余白・タイポグラフィの一元管理。
/// 和紙のようなやわらかい地色と、読みやすい藍色の文字を基調にする。
enum KoyomiTheme {
    // MARK: - 色

    /// 藍色の文字 #1E2A3A
    static let ink = Color(red: 0x1E / 255, green: 0x2A / 255, blue: 0x3A / 255)
    /// 和紙クリーム #FBF8F3
    static let washi = Color(red: 0xFB / 255, green: 0xF8 / 255, blue: 0xF3 / 255)
    /// 夜の地色（純黒ではなく少し青みのある濃紺）#12151C
    static let midnight = Color(red: 0x12 / 255, green: 0x15 / 255, blue: 0x1C / 255)
    /// アクセント（藍） #2F5D8C
    static let accent = Color(red: 0x2F / 255, green: 0x5D / 255, blue: 0x8C / 255)
    /// 日曜の強調色（暗い赤。白背景で 4.5:1 以上）#B3261E
    static let sunday = Color(red: 0xB3 / 255, green: 0x26 / 255, blue: 0x1E / 255)
    /// 土曜の強調色 #1F5FA8
    static let saturday = Color(red: 0x1F / 255, green: 0x5F / 255, blue: 0xA8 / 255)

    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? midnight : washi
    }

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.94) : ink
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.7) : ink.opacity(0.66)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.07) : Color.white
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.14) : ink.opacity(0.08)
    }

    static func sundayText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0xFF / 255, green: 0x8A / 255, blue: 0x80 / 255) : sunday
    }

    static func saturdayText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0x8A / 255, green: 0xB8 / 255, blue: 0xFF / 255) : saturday
    }

    // MARK: - 余白と角丸

    enum Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 16
        static let l: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 18
        static let small: CGFloat = 10
    }

    /// タップ領域の最小サイズ（44×44pt）。
    static let minimumTapTarget: CGFloat = 44

    // MARK: - タイポグラフィ（システム日本語フォント + Dynamic Type）

    static let titleFont = Font.system(.title2).weight(.semibold)
    static let headlineFont = Font.system(.headline)
    static let bodyFont = Font.system(.body)
    static let captionFont = Font.system(.caption)

    /// HEX を Color に変換する。不正な値ではアクセント色にフォールバックする。
    static func color(hex: String) -> Color {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let intValue = Int(value, radix: 16) else { return accent }
        return Color(
            red: Double((intValue >> 16) & 0xFF) / 255,
            green: Double((intValue >> 8) & 0xFF) / 255,
            blue: Double(intValue & 0xFF) / 255
        )
    }

    /// シフト色。ラベル背景に使い、文字は白で表示する。
    static func color(_ shiftColor: ShiftColor) -> Color {
        color(hex: shiftColor.hex)
    }
}
