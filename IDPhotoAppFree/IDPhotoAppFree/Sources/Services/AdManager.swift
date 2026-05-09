import SwiftUI
import GoogleMobileAds

// MARK: - 広告ユニットID
// ─────────────────────────────────────────────────────────
// アプリ名   : 証明写真 - ID Photo Maker
// AdMob App ID: ca-app-pub-7019246421185381~9309653692
// ─────────────────────────────────────────────────────────
enum AdUnitID {
    #if DEBUG
    // ── テスト用 ID（Google 公式テスト広告）──
    static let appID        = "ca-app-pub-3940256099942544~1458002511"
    static let banner       = "ca-app-pub-3940256099942544/2934735716"
    static let interstitial = "ca-app-pub-3940256099942544/4411468910"
    #else
    // ── 本番用 ID ──
    static let appID        = "ca-app-pub-7019246421185381~9309653692"
    static let banner       = "ca-app-pub-7019246421185381/1978926183"
    static let interstitial = "ca-app-pub-7019246421185381/4413517839"
    #endif
}

// MARK: - AdManager（インタースティシャル）
@MainActor
final class AdManager: NSObject, ObservableObject {

    @Published private(set) var isAdReady = false

    private var interstitialAd: GADInterstitialAd?

    override init() {
        super.init()
        loadInterstitial()
    }

    // インタースティシャルを事前ロード
    func loadInterstitial() {
        Task {
            do {
                interstitialAd = try await GADInterstitialAd.load(
                    withAdUnitID: AdUnitID.interstitial,
                    request: GADRequest()
                )
                interstitialAd?.fullScreenContentDelegate = self
                isAdReady = true
            } catch {
                print("[AdManager] インタースティシャルロード失敗: \(error.localizedDescription)")
                isAdReady = false
            }
        }
    }

    // インタースティシャルを表示
    func showInterstitial(from root: UIViewController) {
        guard let ad = interstitialAd else {
            print("[AdManager] 広告未準備")
            return
        }
        ad.present(fromRootViewController: root)
    }

    // 現在の UIViewController を取得するヘルパー
    func currentRootViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return nil }
        var top = root
        while let presented = top.presentedViewController { top = presented }
        return top
    }
}

// MARK: - GADFullScreenContentDelegate
extension AdManager: GADFullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            // 広告閉じた後に次の広告をプリロード
            self.interstitialAd = nil
            self.isAdReady = false
            self.loadInterstitial()
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        print("[AdManager] 表示失敗: \(error.localizedDescription)")
        Task { @MainActor in
            self.interstitialAd = nil
            self.isAdReady = false
            self.loadInterstitial()
        }
    }
}

// MARK: - バナー広告 SwiftUI Wrapper
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.rootViewController
        banner.load(GADRequest())
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}

// MARK: - バナー広告コンテナ（高さ固定）
struct BannerAdContainer: View {
    var body: some View {
        BannerAdView(adUnitID: AdUnitID.banner)
            .frame(width: UIScreen.main.bounds.width, height: 50)
            .background(Color(.systemBackground))
    }
}
