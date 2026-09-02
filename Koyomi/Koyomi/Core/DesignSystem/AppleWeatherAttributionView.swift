import SwiftUI

/// WeatherKit の表示に必要な Apple Weather の帰属表示。
struct AppleWeatherAttributionView: View {
    private static let legalAttributionURL = URL(
        string: "https://weatherkit.apple.com/legal-attribution.html"
    )!

    var body: some View {
        Link(destination: Self.legalAttributionURL) {
            HStack(spacing: 4) {
                Text(" Weather")
                Image(systemName: "arrow.up.right")
                    .font(.caption2)
            }
            .font(KoyomiTheme.captionFont)
        }
        .accessibilityLabel("Apple Weather データ提供元と法的帰属情報")
    }
}
