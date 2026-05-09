import SwiftUI

// 注意：确保在 Xcode 中打开 SeeNews.xcworkspace（而不是 .xcodeproj）
// 在 pod install 成功后，GoogleMobileAds 才可用
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - 主入口
@main
struct SeeNewsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var viewModel = NewsViewModel()
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @StateObject private var aiService = AIAnalysisService.shared
    @StateObject private var userManager = UserManager.shared
    @StateObject private var purchaseManager = PurchaseManager.shared
    
    init() {
        // Google Mobile Ads SDK 初始化
        #if canImport(GoogleMobileAds)
        MobileAds.shared.start(completionHandler: nil)
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .environmentObject(subscriptionManager)
                .environmentObject(aiService)
                .environmentObject(userManager)
                .environmentObject(purchaseManager)
        }
    }
}

// MARK: - AppDelegate 扩展（用于处理远程通知）
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        return true
    }
    
    // 处理设备令牌
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device Token: \(token)")
        
        // 保存设备令牌到 UserDefaults
        UserDefaults.standard.set(token, forKey: "deviceToken")
    }
    
    // 处理注册错误
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ Failed to register for remote notifications: \(error)")
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
            
            CategoryView()
                .tabItem {
                    Label("カテゴリ", systemImage: "square.grid.2x2.fill")
                }
                .tag(2)
            
            BookmarkView()
                .tabItem {
                    Label("保存済み", systemImage: "bookmark.fill")
                }
                .tag(3)
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .accentColor(.red)
        .preferredColorScheme(colorScheme)
    }
}
