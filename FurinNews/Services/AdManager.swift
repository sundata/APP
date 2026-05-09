import SwiftUI
import GoogleMobileAds
import Combine

// MARK: - 広告マネージャー
@MainActor
final class AdManager: ObservableObject {
    static let shared = AdManager()

    // ── 広告ユニットID ──
    struct AdUnitID {
        #if DEBUG
        // テスト用 Google 提供の広告ID
        static let banner = "ca-app-pub-3940256099942544/6300978111"
        static let appOpen = "ca-app-pub-3940256099942544/5662855259"
        static let interstitial = "ca-app-pub-3940256099942544/1033173712"
        #else
        // 本番用
        static let banner = "ca-app-pub-7019246421185381/3583045026"
        static let appOpen = "ca-app-pub-7019246421185381/6508591261"
        static let interstitial = "ca-app-pub-7019246421185381/1429541475"
        #endif
    }

    // ── プレミアム状態 ──
    @Published private(set) var isPremiumUser: Bool = false

    // ── インタースティシャル ──
    @Published private(set) var interstitialAd: GADInterstitialAd?
    @Published private(set) var isInterstitialReady = false

    // ── インタースティシャル表示間隔制御 ──
    private var lastInterstitialTime: Date = .distantPast
    private let interstitialInterval: TimeInterval = 120  // 最低2分間隔

    // ── StoreManager 監視 ──
    private var cancellables = Set<AnyCancellable>()
    private var isConfigured = false
    private var isLoadingInterstitial = false

    private init() {
        // StoreManagerの購入状態を監視
        StoreManager.shared.$purchasedProductIDs
            .map { !$0.isEmpty }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPremium in
                guard let self = self else { return }
                let wasPremium = self.isPremiumUser
                self.isPremiumUser = isPremium
                if isPremium {
                    self.interstitialAd = nil
                    self.isInterstitialReady = false
                    print("[AdManager] Premium user detected — ads disabled")
                } else {
                    guard self.isConfigured else { return }
                    self.loadInterstitial()
                    if wasPremium {
                        print("[AdManager] Premium expired — ads re-enabled")
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 初期化（App起動時）
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        // 初期プレミアム状態を反映
        isPremiumUser = StoreManager.shared.isPremiumUser

        // DEBUG モードで テスト広告を設定
        #if DEBUG
        let request = GADMobileAds.sharedInstance().requestConfiguration
        request.testDeviceIdentifiers = [
            "1164d9452a7b17b214bce99c713eff41",
            "2c63a2da7a6d671b03e7e2fb358a1117"
        ]
        print("[AdManager] Test device configured for DEBUG mode")
        #endif

        // GoogleMobileAds初期化（必須）
        GADMobileAds.sharedInstance().start { status in
            print("[AdManager] Google Mobile Ads SDK initialized")
        }
        
        if !isPremiumUser {
            print("[AdManager] Free user — ready to display ads")
        } else {
            print("[AdManager] Premium user — ads disabled")
        }
    }

    // MARK: - 広告表示すべきか
    var shouldShowAds: Bool {
        !isPremiumUser
    }

    // MARK: - インタースティシャル読み込み
    func loadInterstitial() {
        guard isConfigured, shouldShowAds, !isInterstitialReady, !isLoadingInterstitial else { return }
        isLoadingInterstitial = true

        GADInterstitialAd.load(
            withAdUnitID: AdUnitID.interstitial,
            request: GADRequest()
        ) { [weak self] ad, error in
            Task { @MainActor in
                guard let self = self else { return }
                self.isLoadingInterstitial = false
                if let error = error {
                    print("[AdManager] Interstitial load error: \(error.localizedDescription)")
                    return
                }
                guard self.shouldShowAds else { return }
                self.interstitialAd = ad
                self.isInterstitialReady = true
                print("[AdManager] Interstitial loaded successfully")
            }
        }
    }

    // MARK: - インタースティシャル表示
    func showInterstitial(from viewController: UIViewController?) {
        guard shouldShowAds else { return }
        guard let vc = viewController else { return }
        guard let ad = interstitialAd else {
            print("[AdManager] No interstitial ad ready")
            return
        }

        // 間隔制御
        let now = Date()
        guard now.timeIntervalSince(lastInterstitialTime) >= interstitialInterval else {
            print("[AdManager] Interstitial interval too short, skipping")
            return
        }

        ad.present(fromRootViewController: vc)
        lastInterstitialTime = now
        isInterstitialReady = false
        interstitialAd = nil

        // 次の広告を事前読み込み
        loadInterstitial()
    }
}

// MARK: - Banner広告 UIViewRepresentable
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    var onLoad: (() -> Void)?
    var onFail: ((Error) -> Void)?

    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = adUnitID
        banner.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        banner.load(GADRequest())
        banner.delegate = context.coordinator
        return banner
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoad: onLoad, onFail: onFail)
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        let onLoad: (() -> Void)?
        let onFail: ((Error) -> Void)?

        init(onLoad: (() -> Void)?, onFail: ((Error) -> Void)?) {
            self.onLoad = onLoad
            self.onFail = onFail
        }

        func bannerViewDidReceiveAd(_ bannerView: GADBannerView) {
            print("[AdManager] Banner ad loaded")
            onLoad?()
        }
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            print("[AdManager] Banner ad error: \(error.localizedDescription)")
            onFail?(error)
        }
    }
}

// MARK: - 広告 or プレミアム誘導 View
struct AdOrPremiumView: View {
    @ObservedObject private var adManager = AdManager.shared
    @ObservedObject private var storeManager = StoreManager.shared
    var onLoad: (() -> Void)?
    var onFail: ((Error) -> Void)?

    var body: some View {
        Group {
            if !storeManager.isPremiumUser && adManager.shouldShowAds {
                HStack {
                    Spacer(minLength: 0)
                    BannerAdView(
                        adUnitID: AdManager.AdUnitID.banner,
                        onLoad: onLoad,
                        onFail: onFail
                    )
                        .frame(width: GADAdSizeBanner.size.width, height: GADAdSizeBanner.size.height)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .frame(height: GADAdSizeBanner.size.height)
            } else {
                EmptyView()
                    .frame(height: 0)
            }
        }
    }
}

// MARK: - ニュースリスト内広告
struct InlineBannerAdRow: View {
    @State private var loadState: BannerLoadState = .loading

    var body: some View {
        Group {
            if loadState != .failed {
                VStack(spacing: 0) {
                    Divider().padding(.leading, 16)

                    VStack(spacing: 6) {
                        if loadState == .loaded {
                            Text("広告")
                                .font(FontScaler.caption2())
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                        }

                        AdOrPremiumView {
                            loadState = .loaded
                        } onFail: { _ in
                            loadState = .failed
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, loadState == .loaded ? 10 : 0)
                    .frame(maxWidth: .infinity)
                    .background(loadState == .loaded ? Color(.secondarySystemBackground) : Color.clear)

                    if loadState == .loaded {
                        Divider().padding(.leading, 16)
                    }
                }
                .task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    if loadState == .loading {
                        loadState = .failed
                        print("[AdManager] Banner ad timed out before loading")
                    }
                }
            }
        }
    }

    private enum BannerLoadState {
        case loading
        case loaded
        case failed
    }
}

enum AdPlacement {
    static func shouldShowInlineBanner(after index: Int) -> Bool {
        let position = index + 1
        return position >= 3 && (position - 3).isMultiple(of: 8)
    }
}

// MARK: - インタースティシャル表示ヘルパー
struct InterstitialAdHelper {
    /// 現在のKeyWindowのrootViewControllerを取得
    static func topViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else {
            return nil
        }
        return getTopVC(from: root)
    }

    private static func getTopVC(from vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController {
            return getTopVC(from: presented)
        }
        if let nav = vc as? UINavigationController, let visible = nav.visibleViewController {
            return getTopVC(from: visible)
        }
        if let tab = vc as? UITabBarController, let selected = tab.selectedViewController {
            return getTopVC(from: selected)
        }
        return vc
    }
}
