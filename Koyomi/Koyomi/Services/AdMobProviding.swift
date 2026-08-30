import SwiftUI
import Observation
import GoogleMobileAds
import UserMessagingPlatform

/// AdMob の初期化とプライバシー同意を一か所で管理する。
@MainActor
@Observable
final class AdMobProvider {
    static let shared = AdMobProvider()

    private(set) var canShowAds = false
    private(set) var privacyOptionsRequired = false
    private var hasStartedAds = false
    private var isPreparing = false

    /// Koyomi の AdMob バナー広告ユニット ID。
    static let bannerAdUnitID = "ca-app-pub-7019246421185381/2043518402"

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
            Task { @MainActor in self?.canShowAds = true }
        }
    }
}
