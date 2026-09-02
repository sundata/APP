import SwiftUI
import GoogleMobileAds

/// SwiftUI から Google Mobile Ads の自適応バナーを表示するラッパー。
struct AdMobBannerView: View {
    let adUnitID: String

    var body: some View {
        BannerContainer(adSize: AdSizeBanner, adUnitID: adUnitID)
            .frame(width: AdSizeBanner.size.width, height: AdSizeBanner.size.height)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: AdSizeBanner.size.height)
        // GoogleMobileAds の UIKit ビューが SwiftUI の予約領域外へ描画されないようにする。
        .clipped()
        .accessibilityLabel("広告")
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.clipsToBounds = true
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) else { return }
        banner.adSize = adSize
        banner.load(Request())
    }
}
