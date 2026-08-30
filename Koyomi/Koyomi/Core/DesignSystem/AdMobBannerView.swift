import SwiftUI
import GoogleMobileAds

/// SwiftUI から Google Mobile Ads の自適応バナーを表示するラッパー。
struct AdMobBannerView: View {
    let adUnitID: String

    var body: some View {
        GeometryReader { proxy in
            let width = max(320, proxy.size.width)
            let adSize = largeAnchoredAdaptiveBanner(width: width)
            BannerContainer(adSize: adSize, adUnitID: adUnitID)
                .frame(width: adSize.size.width, height: adSize.size.height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 60)
        .accessibilityLabel("広告")
    }
}

private struct BannerContainer: UIViewRepresentable {
    let adSize: AdSize
    let adUnitID: String

    func makeUIView(context: Context) -> BannerView {
        let banner = BannerView(adSize: adSize)
        banner.adUnitID = adUnitID
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) else { return }
        banner.adSize = adSize
        banner.load(Request())
    }
}
