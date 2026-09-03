import SwiftUI
import SwimFinderCore

struct RootView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("ホーム", systemImage: "house") }
                .accessibilityIdentifier("tab.home")
            AthleteHubView()
                .tabItem { Label("マイ選手", systemImage: "person.2.fill") }
                .accessibilityIdentifier("tab.athletes")
            FavoritesView()
                .tabItem { Label("お気に入り", systemImage: "star") }
                .accessibilityIdentifier("tab.favorites")
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
                .accessibilityIdentifier("tab.settings")
        }
        .tint(SwimFinderTheme.officialBlue)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(.ultraThinMaterial, for: .tabBar)
    }
}
