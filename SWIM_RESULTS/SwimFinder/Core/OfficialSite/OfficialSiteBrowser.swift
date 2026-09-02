import Observation
import SafariServices
import SwiftUI
import SwimFinderCore

/// 公式サイト表示の状態。URL は公式サイトのものだけを受け付ける。
@MainActor
@Observable
final class OfficialSiteBrowser {
    struct Request: Identifiable {
        let id = UUID()
        let url: URL
        let guidance: String
    }

    private(set) var current: Request?
    /// UI テスト中は Safari を開かず、確認用の画面を出す。
    let isUITesting: Bool

    init(isUITesting: Bool) {
        self.isUITesting = isUITesting
    }

    func open(_ plan: OfficialSiteLaunch.Plan) {
        guard OfficialSite.isOfficialURL(plan.url) else { return }
        current = Request(url: plan.url, guidance: plan.guidance)
    }

    func open(url: URL) {
        guard let plan = OfficialSiteLaunch.reopen(url) else { return }
        open(plan)
    }

    func dismiss() {
        current = nil
    }
}

/// SFSafariViewController のラッパー。公式サイトをそのまま表示し、DOM 注入や自動操作は行わない。
struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let configuration = SFSafariViewController.Configuration()
        configuration.entersReaderIfAvailable = false
        let controller = SFSafariViewController(url: url, configuration: configuration)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

/// 公式サイトを開く直前の案内 + Safari 表示。
struct OfficialSiteSheet: View {
    let request: OfficialSiteBrowser.Request
    let isUITesting: Bool
    let onClose: () -> Void

    var body: some View {
        if isUITesting {
            NavigationStack {
                VStack(alignment: .leading, spacing: SwimFinderTheme.spacing) {
                    Text("公式サイトを開きます（テストモード）")
                        .font(.headline)
                    Text(request.url.absoluteString)
                        .font(.footnote)
                        .accessibilityIdentifier("officialURLLabel")
                    Text(request.guidance)
                        .font(.body)
                        .accessibilityIdentifier("guidanceLabel")
                    Spacer()
                }
                .padding()
                .navigationTitle("公式サイト")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる", action: onClose).accessibilityIdentifier("closeOfficialSite")
                    }
                }
            }
        } else {
            SafariView(url: request.url)
                .ignoresSafeArea()
        }
    }
}
