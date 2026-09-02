import SwiftUI

enum SwimFinderTheme {
    /// 最小タップ領域（HIG）
    static let minimumTapSize: CGFloat = 44
    static let cornerRadius: CGFloat = 12
    static let spacing: CGFloat = 12
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
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: SwimFinderTheme.cornerRadius))
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
