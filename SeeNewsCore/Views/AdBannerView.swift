import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - AdMob Banner

struct AdBannerView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    var placement: AdPlacement = .homeTop

    var body: some View {
        if viewModel.userSubscription.plan == .free {
            VStack(spacing: 6) {
                HStack {
                    Text("スポンサー広告")
                        .font(FontScaler.font(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Proプランで非表示")
                        .font(FontScaler.font(size: 10))
                        .foregroundColor(.secondary)
                }

                RealAdMobBannerView(placement: placement)
                    .frame(height: placement.height)
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, placement.verticalPadding)
        }
    }
}

enum AdPlacement {
    case homeTop
    case listInline

    var height: CGFloat {
        switch self {
        case .homeTop: return 60
        case .listInline: return 50
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .homeTop: return 8
        case .listInline: return 6
        }
    }
}

struct AdListItemView: View {
    @EnvironmentObject var viewModel: NewsViewModel

    var body: some View {
        AdBannerView(placement: .listInline)
            .environmentObject(viewModel)
    }
}

#if canImport(GoogleMobileAds)
private struct RealAdMobBannerView: UIViewRepresentable {
    let placement: AdPlacement

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView(adSize: AdSizeBanner)
        bannerView.adUnitID = AdMobManager.shared.getBannerAdUnitID()
        bannerView.rootViewController = UIApplication.shared.adRootViewController
        bannerView.delegate = context.coordinator
        bannerView.load(Request())
        return bannerView
    }

    func updateUIView(_ bannerView: BannerView, context: Context) {
        if bannerView.rootViewController == nil {
            bannerView.rootViewController = UIApplication.shared.adRootViewController
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            print("AdMob banner failed: \(error.localizedDescription)")
        }
    }
}

private extension UIApplication {
    var adRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
#else
private struct RealAdMobBannerView: View {
    let placement: AdPlacement

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.3.group")
                .foregroundColor(.secondary)
            Text("AdMob SDK が見つかりません")
                .font(FontScaler.caption())
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: placement.height)
    }
}
#endif
