import SwiftUI
import UIKit

// MARK: - Color Extensions

extension Color {
    /// Hex文字列から Color を生成 (#RGB, #RRGGBB, #RRGGBBAA)
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red:     Double(r) / 255,
            green:   Double(g) / 255,
            blue:    Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // MARK: - アプリブランドカラー（デザイントークン）

    /// プライマリブルー（ボタン・アイコン主色）
    static let appPrimary       = Color(hex: "#2471C8")
    /// アクセントブルー（ハイライト・リンク）
    static let appAccent        = Color(hex: "#4AAFFF")
    /// ページ背景（薄いグレー）
    static let appBackground    = Color(hex: "#F4F6FA")
    /// カード・シート背景（白）
    static let appSurface       = Color(hex: "#FFFFFF")
    /// プライマリテキスト（深い紺）
    static let appTextPrimary   = Color(hex: "#1A2B3C")
    /// セカンダリテキスト（ミドルグレー）
    static let appTextSecondary = Color(hex: "#6B7C8D")
    /// 区切り線・ボーダー
    static let appDivider       = Color(hex: "#E4E8EE")
    /// 成功グリーン
    static let appSuccess       = Color(hex: "#34C759")
    /// 警告オレンジ
    static let appWarning       = Color(hex: "#FF9500")
    /// エラーレッド
    static let appDanger        = Color(hex: "#FF3B30")

    // MARK: - ヘッダーグラデーション
    static let headerGradient = LinearGradient(
        colors: [Color(hex: "#0D2744"), Color(hex: "#1A4A7A"), Color(hex: "#2C7EC8")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - プライマリグラデーション
    static let primaryGradient = LinearGradient(
        colors: [Color(hex: "#2A7EF5"), Color(hex: "#1A5FC7")],
        startPoint: .leading,
        endPoint: .trailing
    )

    // MARK: - Hex文字列変換
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X",
                      Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - UIColor Extensions

extension UIColor {
    convenience init?(hex: String) {
        var hexStr = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexStr.hasPrefix("#") { hexStr.removeFirst() }
        guard hexStr.count == 6 || hexStr.count == 8 else { return nil }
        var rgbValue: UInt64 = 0
        Scanner(string: hexStr).scanHexInt64(&rgbValue)
        let r, g, b, a: CGFloat
        if hexStr.count == 8 {
            r = CGFloat((rgbValue & 0xFF000000) >> 24) / 255
            g = CGFloat((rgbValue & 0x00FF0000) >> 16) / 255
            b = CGFloat((rgbValue & 0x0000FF00) >> 8)  / 255
            a = CGFloat( rgbValue & 0x000000FF)         / 255
        } else {
            r = CGFloat((rgbValue & 0xFF0000) >> 16) / 255
            g = CGFloat((rgbValue & 0x00FF00) >> 8)  / 255
            b = CGFloat( rgbValue & 0x0000FF)         / 255
            a = 1.0
        }
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

// MARK: - Haptic Feedback

struct HapticFeedback {
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()    { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()  { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()    { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection(){ UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Animation Tokens

extension Animation {
    /// 標準的なスプリング（画面遷移・カード）
    static let appSpring      = Animation.spring(response: 0.38, dampingFraction: 0.72)
    /// 軽快なスプリング（ボタン・選択）
    static let appQuickSpring = Animation.spring(response: 0.28, dampingFraction: 0.68)
    /// ゆったりスプリング（ヒーロー・大型アニメ）
    static let appSlowSpring  = Animation.spring(response: 0.55, dampingFraction: 0.78)
    /// 標準イーズイン・アウト
    static let appEase        = Animation.easeInOut(duration: 0.22)
    /// 高速フェード
    static let appFade        = Animation.easeInOut(duration: 0.15)
}

// MARK: - View Modifiers

struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var shadowRadius: CGFloat = 8
    var shadowOpacity: Double = 0.08

    func body(content: Content) -> some View {
        content
            .background(Color.appSurface)
            .cornerRadius(cornerRadius)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: shadowRadius, x: 0, y: 3)
    }
}

struct FloatingCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appSurface)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.12), radius: 18, x: 0, y: 6)
    }
}

/// タップしたときに薄いリップルエフェクトを出すオーバーレイ
/// NOTE: DragGesture は Button の tap を奪うため使用禁止。
/// ScaleButtonStyle の isPressed を通じてアニメーションさせる。
struct TapHighlightModifier: ViewModifier {
    var cornerRadius: CGFloat = 14

    func body(content: Content) -> some View {
        // 視覚的オーバーレイのみ。タッチイベントを奪わない。
        content
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.clear)
                    .allowsHitTesting(false)
            )
    }
}

extension View {
    func cardStyle(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius, shadowRadius: shadowRadius))
    }
    func floatingCard() -> some View {
        modifier(FloatingCardStyle())
    }
    func tapHighlight(cornerRadius: CGFloat = 14) -> some View {
        modifier(TapHighlightModifier(cornerRadius: cornerRadius))
    }
}

// MARK: - Button Styles

/// プライマリボタン（グラデーション、シャドウ付き）
struct PrimaryButtonStyle: ButtonStyle {
    var isFullWidth: Bool = true
    var verticalPadding: CGFloat = 16

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, verticalPadding)
            .padding(.horizontal, 24)
            .background(Color.primaryGradient)
            .cornerRadius(14)
            .shadow(color: Color.appPrimary.opacity(configuration.isPressed ? 0.2 : 0.38),
                    radius: configuration.isPressed ? 4 : 10, x: 0, y: configuration.isPressed ? 2 : 5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.appQuickSpring, value: configuration.isPressed)
    }
}

/// セカンダリボタン（アウトライン）
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.appPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.appPrimary.opacity(0.07))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.appQuickSpring, value: configuration.isPressed)
    }
}

/// スケールアニメーション付きボタンスタイル（汎用）
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .brightness(configuration.isPressed ? -0.06 : 0)
            .animation(.appQuickSpring, value: configuration.isPressed)
    }
}

/// テキストのみのボタン（ハイライトなし）
struct PlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.appFade, value: configuration.isPressed)
    }
}

// MARK: - Shimmer Effect（スケルトンローディング）

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    let gradient = LinearGradient(
                        stops: [
                            .init(color: .clear,                              location: 0),
                            .init(color: .white.opacity(0.5),                 location: 0.4),
                            .init(color: .clear,                              location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Rectangle()
                        .fill(gradient)
                        .frame(width: geo.size.width * 2)
                        .offset(x: phase * geo.size.width * 2)
                }
                .clipped()
            )
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - 共通セクションヘッダー

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var trailingContent: AnyView? = nil

    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 19, weight: .bold))
                    .foregroundColor(Color.appTextPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.system(size: 13))
                        .foregroundColor(Color.appTextSecondary)
                }
            }
            Spacer()
            trailingContent
        }
    }
}

// MARK: - バッジラベル

struct BadgeLabel: View {
    let text: String
    var color: Color = .appPrimary
    var textColor: Color = .white
    var fontSize: CGFloat = 10

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold))
            .foregroundColor(textColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(color)
            .cornerRadius(5)
    }
}

// MARK: - 空状態ビュー

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appPrimary.opacity(0.08))
                    .frame(width: 88, height: 88)
                Image(systemName: icon)
                    .font(.system(size: 36))
                    .foregroundColor(Color.appPrimary.opacity(0.5))
            }
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color.appTextPrimary)
                if let msg = message {
                    Text(msg)
                        .font(.system(size: 14))
                        .foregroundColor(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                }
            }
            if let label = actionLabel, let act = action {
                Button(action: act) {
                    Text(label)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.primaryGradient)
                        .cornerRadius(12)
                }
            }
        }
        .padding(32)
    }
}

// MARK: - ステータスインジケーター（● 点滅）

struct PulseDot: View {
    var color: Color = .appSuccess
    @State private var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: 14, height: 14)
                .scaleEffect(scale)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                scale = 1.6
            }
        }
    }
}
