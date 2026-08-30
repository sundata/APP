import SwiftUI
import GoogleMobileAds

// MARK: - 主入口
@main
struct FurinNewsApp: App {
    @StateObject private var viewModel = NewsViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onChange(of: scenePhase) { newPhase in
                    guard newPhase == .active else { return }
                    Task { await viewModel.refreshIfStale() }
                }
        }
    }
}

// MARK: - ContentView（Tab 导航）
struct ContentView: View {
    @EnvironmentObject var viewModel: NewsViewModel
    @AppStorage("selectedAppearance") private var selectedAppearance = 0  // 0=auto, 1=light, 2=dark
    @State private var selectedTab = 0
    
    private var colorScheme: ColorScheme? {
        switch selectedAppearance {
        case 1: return .light
        case 2: return .dark
        default: return nil  // auto → 跟随系统
        }
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("ホーム", systemImage: "house.fill")
                }
                .tag(0)
            
            SearchView()
                .tabItem {
                    Label("検索", systemImage: "magnifyingglass")
                }
                .tag(1)

            BookmarkView()
                .tabItem {
                    Label("保存済み", systemImage: "bookmark.fill")
                }
                .tag(2)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .accentColor(.red)
        .preferredColorScheme(colorScheme)
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            AdManager.shared.configure()

            try? await Task.sleep(nanoseconds: 500_000_000)
            await StoreManager.shared.loadProducts()
            AdManager.shared.loadInterstitial()
        }
    }
}
