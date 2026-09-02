import SwiftUI
import Observation
import GoogleMobileAds
import UserMessagingPlatform

/// AdMob の初期化とプライバシー同意を一か所で管理する。
@MainActor
@Observable
final class AdMobProvider: NSObject, FullScreenContentDelegate {
    static let shared = AdMobProvider()

    private(set) var canShowAds = false
    private(set) var privacyOptionsRequired = false
    private var hasStartedAds = false
    private var isPreparing = false
    private var interstitialAd: InterstitialAd?
    private var hasShownInterstitialThisSession = false

    /// Koyomi の本番 AdMob 広告ユニット ID。
    static let productionBannerAdUnitID = "ca-app-pub-7019246421185381/1403675992"
    static let productionInterstitialAdUnitID = "ca-app-pub-7019246421185381/1048452776"

    /// 開発中は Google 公式テスト広告を使い、無効なトラフィックを発生させない。
    static var bannerAdUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/2435281174"
        #else
        productionBannerAdUnitID
        #endif
    }

    private static var interstitialAdUnitID: String {
        #if DEBUG
        "ca-app-pub-3940256099942544/4411468910"
        #else
        productionInterstitialAdUnitID
        #endif
    }

    func prepare() async {
        guard !isPreparing, !hasStartedAds else { return }
        isPreparing = true
        defer { isPreparing = false }
        let parameters = RequestParameters()

        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }

        do {
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // 以前の有効な同意状態があれば、下の canRequestAds で継続できる。
        }

        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
        guard ConsentInformation.shared.canRequestAds else { return }
        startAdsIfNeeded()
    }

    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            return
        }
        canShowAds = ConsentInformation.shared.canRequestAds
    }

    private func startAdsIfNeeded() {
        guard !hasStartedAds else {
            canShowAds = true
            return
        }
        hasStartedAds = true
        MobileAds.shared.start { [weak self] _ in
            Task { @MainActor in
                self?.canShowAds = true
                await self?.loadInterstitial()
            }
        }
    }

    /// シェアカードを閉じた後など、自然な区切りでのみ呼び出す。
    func presentInterstitialIfAvailable() {
        guard !hasShownInterstitialThisSession, let interstitialAd else { return }
        do {
            try interstitialAd.canPresent(from: nil)
            hasShownInterstitialThisSession = true
            self.interstitialAd = nil
            interstitialAd.present(from: nil)
        } catch {
            self.interstitialAd = nil
            Task { await loadInterstitial() }
        }
    }

    private func loadInterstitial() async {
        guard interstitialAd == nil, !hasShownInterstitialThisSession else { return }
        do {
            let ad = try await InterstitialAd.load(
                with: Self.interstitialAdUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            interstitialAd = ad
        } catch {
            interstitialAd = nil
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        interstitialAd = nil
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        interstitialAd = nil
    }
}
