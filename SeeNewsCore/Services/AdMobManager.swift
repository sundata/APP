import Foundation
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Google AdMob マネージャー（フレームワーク）
class AdMobManager: NSObject {
    static let shared = AdMobManager()
    
    // AdMob IDs
    // 在 Google AdMob 控制板获取这些 ID：https://admob.google.com
    private let appID = "ca-app-pub-7019246421185381~8398499848"  // SeeNews 应用 ID
    private let bannerAdID = "ca-app-pub-7019246421185381/4521556321"  // Banner Ad Unit ID (生产环境)
    private let testBannerAdID = "ca-app-pub-3940256099942544/2934735716"  // Banner Ad Unit ID (iOS Test ID)
    private let interstitialAdID = "ca-app-pub-3940256099942544/1033173712"  // Interstitial Ad Unit ID (Test ID)
    private let rewardedAdID = "ca-app-pub-3940256099942544/5224354917"  // Rewarded Ad Unit ID (Test ID)
    
    // 可用的测试设备 ID（用于开发）
    private let testDeviceIDs = [
        "33BE2250B43518CCDA7DE426D04EE232"  // iPhone simulator
    ]
    
    override init() {
        super.init()
        setupAdMob()
    }
    
    // MARK: - 初期化
    private func setupAdMob() {
        #if canImport(GoogleMobileAds)
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = testDeviceIDs
        #endif
    }
    
    // MARK: - Banner 广告（用于页面顶部）
    /// 为 AdBannerView 返回 Banner Ad Unit ID
    func getBannerAdUnitID() -> String {
        #if DEBUG
        return testBannerAdID
        #else
        return bannerAdID
        #endif
    }
    
    // MARK: - 原生广告（用于列表插入）
    /// 为 AdListItemView 返回 Native Ad Unit ID
    func getNativeAdUnitID() -> String {
        // Google AdMob 原生广告单元 ID
        // 用于更好地集成到列表中
        return "ca-app-pub-3940256099942544/2247696110"
    }
    
    // MARK: - 插页式广告（可选：在 tab 切换时显示）
    /// 获取插页式广告单元 ID
    func getInterstitialAdUnitID() -> String {
        return interstitialAdID
    }
    
    // MARK: - 有奖励视频广告（可选：用户看视频获得额外配额）
    /// 获取有奖励视频广告单元 ID（用于提供免费 AI 分析次数）
    func getRewardedAdUnitID() -> String {
        return rewardedAdID
    }
    
    // MARK: - 广告配置
    struct AdConfiguration {
        /// 免费用户是否显示广告
        let showAdsForFreeUser: Bool = true
        
        /// Pro 用户是否显示广告
        let showAdsForProUser: Bool = false
        
        /// 列表中每几篇文章显示一次广告
        let adFrequency: Int = 3  // 每 3 篇文章显示1个广告
        
        /// 是否启用个性化广告
        let enablePersonalizedAds: Bool = true
        
        /// 是否在模拟器上显示测试广告
        let useTestAds: Bool = true
    }
    
    let configuration = AdConfiguration()
}

// MARK: - AdMob 集成步骤说明
/*
 
 ========================================
 Google AdMob 集成指南
 ========================================
 
 1. 创建 Google AdMob 账户
    - 访问 https://admob.google.com
    - 使用 Google 账号登录
    - 添加新应用
 
 2. 获取 AdMob IDs
    - App ID: ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy
    - Banner Ad Unit ID: ca-app-pub-3940256099942544/6300978111 (测试)
    - 在 Info.plist 中添加 GADApplicationIdentifier
 
 3. 安装 Google Mobile Ads SDK
    - 打开项目的 Podfile（如果没有请创建）
    - 添加: pod 'Google-Mobile-Ads-SDK'
    - 运行: pod install
 
 4. 在 Info.plist 中配置 AdMob
    <dict>
        ...
        <key>GADApplicationIdentifier</key>
        <string>ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy</string>
        ...
    </dict>
 
 5. 在 SeeNewsApp.swift 中初始化 AdMob
    @main
    struct SeeNewsApp: App {
        init() {
            // Google Mobile Ads SDK の初期化
            // GADMobileAds.sharedInstance().start()
        }
        ...
    }
 
 6. 创建 SwiftUI Wrapper（AdMobBannerView.swift）
    使用 UIViewRepresentable 来包装 GADBannerView
 
 7. 使用广告视图
    - 在 HomeView 中使用 AdMobBannerView
    - 在列表中插入原生广告
 
 8. 测试
    - 使用测试 Ad Unit IDs（见下方）
    - 在真实设备上测试
    - 避免过度点击测试广告（会导致账户被封）
 
 ========================================
 测试用的 Ad Unit IDs (Google 提供)
 ========================================
 
 Banner Ads:
 ca-app-pub-3940256099942544/6300978111
 
 Interstitial Ads:
 ca-app-pub-3940256099942544/1033173712
 
 Rewarded Ads:
 ca-app-pub-3940256099942544/5224354917
 
 Native Advanced:
 ca-app-pub-3940256099942544/2247696110
 
 ========================================
 隐私政策
 ========================================
 
 确保:
 1. 在应用描述中声明使用 Google 广告
 2. 添加隐私政策链接（必需）
 3. 遵守 AdMob 政策避免账户被禁用
 4. 不要点击自己的广告
 5. 不要刷广告展示次数
 
 */
