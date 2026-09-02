import SwiftUI
import SwimFinderCore

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let browser = environment.browser
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
                .accessibilityIdentifier("tab.home")
            FavoritesView()
                .tabItem { Label("お気に入り", systemImage: "star") }
                .accessibilityIdentifier("tab.favorites")
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .accessibilityIdentifier("tab.settings")
        }
        .fullScreenCover(
            item: Binding(get: { browser.current }, set: { if $0 == nil { browser.dismiss() } })
        ) { request in
            OfficialSiteSheet(request: request, isUITesting: browser.isUITesting, onClose: { browser.dismiss() })
        }
    }
}
