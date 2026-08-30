import SwiftUI

/// 色・余白・タイポグラフィの一元管理。
/// 夜空ブルー / ミストパープル / 月光ベージュを基調にする。
enum KoyomiTheme {
    // MARK: - 色

    /// 夜空ブルー #252544
    static let nightSky = Color(red: 0x25 / 255, green: 0x25 / 255, blue: 0x44 / 255)
    /// ミストパープル #8D83B8
    static let mistPurple = Color(red: 0x8D / 255, green: 0x83 / 255, blue: 0xB8 / 255)
    /// 月光ベージュ #FAF7F2
    static let moonBeige = Color(red: 0xFA / 255, green: 0xF7 / 255, blue: 0xF2 / 255)
    /// ダークモードは純黒ではなく深い藍を使う。
    static let deepIndigo = Color(red: 0x14 / 255, green: 0x14 / 255, blue: 0x28 / 255)
    /// ストロベリーミルク #F3A9BC
    static let strawberryMilk = Color(red: 0xF3 / 255, green: 0xA9 / 255, blue: 0xBC / 255)
    /// ピーチクリーム #FFD6C8
    static let peachCream = Color(red: 0xFF / 255, green: 0xD6 / 255, blue: 0xC8 / 255)
    /// ラベンダーミルク #D9C9F2
    static let lavenderMilk = Color(red: 0xD9 / 255, green: 0xC9 / 255, blue: 0xF2 / 255)
    /// バニラ #FFF8E8
    static let vanilla = Color(red: 0xFF / 255, green: 0xF8 / 255, blue: 0xE8 / 255)
    /// ベリー文字色。淡色背景でも十分なコントラストを保つ。
    static let berryInk = Color(red: 0x4B / 255, green: 0x2D / 255, blue: 0x46 / 255)

    static func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? moonBeige : berryInk
    }

    static func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? moonBeige.opacity(0.72) : berryInk.opacity(0.68)
    }

    static func cardFill(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.76)
    }

    static func cardStroke(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.94)
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
        static let card: CGFloat = 24
        static let small: CGFloat = 14
    }

    /// タップ領域の最小サイズ（44×44pt）。
    static let minimumTapTarget: CGFloat = 44

    // MARK: - タイポグラフィ（システム日本語フォント + Dynamic Type）

    static let titleFont = Font.system(.title2, design: .serif).weight(.semibold)
    static let headlineFont = Font.system(.title3, design: .serif).weight(.semibold)
    static let bodyFont = Font.system(.body, design: .default)
    static let captionFont = Font.system(.caption, design: .default)

    /// 幸運色の HEX を Color に変換する。不正な値ではミストパープルにフォールバックする。
    static func color(hex: String) -> Color {
        var value = hex.trimmingCharacters(in: .whitespaces)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let intValue = Int(value, radix: 16) else { return mistPurple }
        return Color(
            red: Double((intValue >> 16) & 0xFF) / 255,
            green: Double((intValue >> 8) & 0xFF) / 255,
            blue: Double(intValue & 0xFF) / 255
        )
    }
}
