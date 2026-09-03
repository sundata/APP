import SwiftUI

enum SwimFinderTheme {
    /// 最小タップ領域（HIG）
    static let minimumTapSize: CGFloat = 44
    static let cornerRadius: CGFloat = 12
    static let spacing: CGFloat = 12
    static let navy = Color(red: 0.035, green: 0.118, blue: 0.255)
    static let officialBlue = Color(red: 0.00, green: 0.35, blue: 0.72)
    static let aqua = Color(red: 0.00, green: 0.68, blue: 0.82)
    static let poolBlue = Color(red: 0.02, green: 0.47, blue: 0.76)
    static let foam = Color(red: 0.88, green: 0.98, blue: 1.00)
    static let canvas = Color(red: 0.925, green: 0.975, blue: 0.99)
    static let success = Color(red: 0.00, green: 0.55, blue: 0.43)
}

/// プールの水面を思わせる、画面共通の控えめな背景。
struct WaterBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [SwimFinderTheme.navy, Color(red: 0.02, green: 0.20, blue: 0.31)]
                    : [SwimFinderTheme.foam, Color(red: 0.82, green: 0.94, blue: 0.98), Color(red: 0.91, green: 0.97, blue: 1.00)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(SwimFinderTheme.aqua.opacity(colorScheme == .dark ? 0.13 : 0.12))
                .frame(width: 310, height: 310)
                .offset(x: 155, y: -260)
            Circle()
                .fill(SwimFinderTheme.officialBlue.opacity(colorScheme == .dark ? 0.16 : 0.08))
                .frame(width: 360, height: 360)
                .blur(radius: 8)
                .offset(x: -190, y: 330)
            VStack(spacing: 34) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule()
                        .stroke(SwimFinderTheme.aqua.opacity(colorScheme == .dark ? 0.08 : 0.10), lineWidth: 1)
                        .frame(width: 310, height: 34)
                        .offset(x: index.isMultiple(of: 2) ? -70 : 85)
                }
            }
            .rotationEffect(.degrees(-7))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct SwimFinderScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background { WaterBackground() }
    }
}

extension View {
    func swimFinderScreen() -> some View {
        modifier(SwimFinderScreenModifier())
    }
}

/// 情報バナー。アイコンと文言で意味を伝え、色だけに依存しない。
struct NoticeBanner: View {
    enum Kind {
        case info, warning

        var symbol: String {
            switch self {
            case .info: return "info.circle"
            case .warning: return "exclamationmark.triangle"
            }
        }

        var accessibilityPrefix: String {
            switch self {
            case .info: return "お知らせ"
            case .warning: return "注意"
            }
        }
    }

    let kind: Kind
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
        } icon: {
            Image(systemName: kind.symbol)
        }
        .padding(SwimFinderTheme.spacing)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: SwimFinderTheme.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: SwimFinderTheme.cornerRadius)
                .stroke(SwimFinderTheme.aqua.opacity(0.32), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.accessibilityPrefix)。\(text)")
    }
}

/// 非公式アプリであることを示す共通表記。
struct UnofficialNotice: View {
    var body: some View {
        NoticeBanner(kind: .info, text: "このアプリは日本水泳連盟および公式結果サイトとは無関係の非公式アプリです。結果は公式サイト（result.swim.or.jp）で確認してください。")
            .accessibilityIdentifier("unofficialNotice")
    }
}
