import SwiftUI
import GoogleMobileAds

/// SwiftUI から Google Mobile Ads の自適応バナーを表示するラッパー。
struct AdMobBannerView: View {
    let adUnitID: String

    /// 小型端末でも本文を圧迫しない、標準バナー相当の表示領域。
    private let bannerHeight: CGFloat = 60

    var body: some View {
        GeometryReader { _ in
            // 公開版でもカレンダーを圧迫しない、固定 320 × 50 の標準バナー。
            BannerContainer(adSize: AdSizeBanner, adUnitID: adUnitID)
                .frame(width: AdSizeBanner.size.width, height: AdSizeBanner.size.height)
                .frame(maxWidth: .infinity)
        }
        .frame(height: bannerHeight)
        // SDK が返すサイズが表示枠を超えても、本文やタブバーへはみ出させない。
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
        banner.load(Request())
        return banner
    }

    func updateUIView(_ banner: BannerView, context: Context) {
        guard !isAdSizeEqualToSize(size1: banner.adSize, size2: adSize) else { return }
        banner.adSize = adSize
        banner.load(Request())
    }
}
