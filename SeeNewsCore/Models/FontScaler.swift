import SwiftUI

// MARK: - 字体缩放工具
/// 读取 @AppStorage("textSizeIndex") 并提供缩放系数
/// 0=小(0.85x), 1=中(1.0x), 2=大(1.2x)
struct FontScaler {
    @AppStorage("textSizeIndex") static var textSizeIndex: Int = 1
    
    private static let multipliers: [CGFloat] = [0.85, 1.0, 1.2]
    
    /// 当前缩放系数
    static var multiplier: CGFloat {
        multipliers[textSizeIndex]
    }
    
    /// 缩放指定字号
    static func scaled(_ size: CGFloat) -> CGFloat {
        size * multiplier
    }
    
    /// 生成缩放后的 Font
    static func font(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        .system(size: scaled(size), weight: weight, design: design)
    }
    
    // MARK: - 语义字体便捷方法（映射 SwiftUI 语义字体到具体大小）
    // iOS 默认: caption2=12, caption=13, footnote=14, subheadline=15, callout=16, body=17, title3=20, title2=22, title=28, headline=17(bold)
    
    /// 缩放 .headline (默认 17pt, bold)
    static func headline(weight: Font.Weight = .bold) -> Font {
        font(size: 17, weight: weight)
    }
    
    /// 缩放 .subheadline (默认 15pt)
    static func subheadline(weight: Font.Weight = .regular) -> Font {
        font(size: 15, weight: weight)
    }
    
    /// 缩放 .caption (默认 13pt)
    static func caption(weight: Font.Weight = .regular) -> Font {
        font(size: 13, weight: weight)
    }
    
    /// 缩放 .caption2 (默认 12pt)
    static func caption2(weight: Font.Weight = .regular) -> Font {
        font(size: 12, weight: weight)
    }
    
    /// 缩放 .title3 (默认 20pt)
    static func title3(weight: Font.Weight = .regular) -> Font {
        font(size: 20, weight: weight)
    }
    
    /// 缩放 .body (默认 17pt)
    static func body(weight: Font.Weight = .regular) -> Font {
        font(size: 17, weight: weight)
    }
}

// MARK: - 环境键注入（可选，方便在 View 中用 @Environment 读取）
private struct FontScalerKey: EnvironmentKey {
    static let defaultValue: CGFloat = FontScaler.multiplier
}

extension EnvironmentValues {
    var fontScale: CGFloat {
        get { self[FontScalerKey.self] }
        set { self[FontScalerKey.self] = newValue }
    }
}
