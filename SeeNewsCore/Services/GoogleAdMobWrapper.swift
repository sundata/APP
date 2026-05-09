import SwiftUI

// MARK: - Google AdMob Banner Wrapper (SwiftUI)
/*
 这个文件提供了 Google AdMob 与 SwiftUI 的集成框架。
 当集成 Google-Mobile-Ads-SDK 后，可以启用这个代码。
 
 集成步骤:
 1. pod install Google-Mobile-Ads-SDK
 2. 在 Info.plist 中添加 GADApplicationIdentifier
 3. 取消注释以下代码
 4. 更新 AdMobManager 中的 Ad Unit IDs
 */

// 当前使用占位符广告（AdBannerView.swift 中的实现）
// 如果需要集成真实 Google AdMob，取消注释以下代码：

/*
import GoogleMobileAds

// MARK: - Banner 广告视图
struct GoogleAdMobBannerView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        let bannerView = GADBannerView(adSize: kGADAdSizeBanner)
        bannerView.adUnitID = AdMobManager.shared.getBannerAdUnitID()
        bannerView.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?
            .windows
            .first?
            .rootViewController
        
        containerView.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            bannerView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            bannerView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
        ])
        
        // 加载广告
        let request = GADRequest()
        bannerView.load(request)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - 原生广告视图
struct GoogleAdMobNativeView: UIViewRepresentable {
    typealias UIViewType = UIView
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        
        let adLoader = GADAdLoader(
            adUnitID: AdMobManager.shared.getNativeAdUnitID(),
            rootViewController: UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first?
                .windows
                .first?
                .rootViewController,
            adTypes: [.native]
        )
        
        // 设置委托并加载广告
        let request = GADRequest()
        adLoader.load(request)
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

*/

// MARK: - 当前使用的占位符实现
// 这是一个临时的占位符，直到实现真实的 Google AdMob 集成
struct GoogleAdMobPlaceholder: View {
    var body: some View {
        VStack {
            Text("AdMob 集成框架已就绪")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Pod 'Google-Mobile-Ads-SDK' 安装后激活真实广告")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - AdMob 集成注意事项
/*
 
 ========================
 重要: 集成 Google AdMob
 ========================
 
 当前状态: 使用体验占位符广告
 
 要启用真实 Google AdMob 广告，请:
 
 1️⃣ 安装 Google Mobile Ads SDK
    Terminal: pod install
    Podfile: pod 'Google-Mobile-Ads-SDK'
 
 2️⃣ 配置 Info.plist
    • 添加 GADApplicationIdentifier
    • 设置 App ID
 
 3️⃣ 获取 Ad Unit IDs
    • 访问 https://admob.google.com
    • 创建你的应用和广告单元
    • 复制 Ad Unit IDs
 
 4️⃣ 更新 AdMobManager.swift
    • 将 appID 替换为你的应用 ID
    • 将 bannerAdID 替换为你的 Banner Ad Unit ID
    • 将 nativeAdID 替换为你的原生 Ad Unit ID
 
 5️⃣ 初始化 AdMob
    在 SeeNewsApp.swift init() 中:
    GADMobileAds.sharedInstance().start()
 
 6️⃣ 取消注释上方的 GoogleAdMobBannerView 和 GoogleAdMobNativeView
 
 7️⃣ 在 HomeView.swift 中替换:
    // 从:
    AdBannerView()
    // 到:
    GoogleAdMobBannerView()
        .frame(height: 50)
 
 ⚠️ 重要提醒:
 • 使用测试 Ad Unit IDs 进行开发
 • 不要点击自己的广告（会导致账户被封）
 • 确保添加了隐私政策
 • 遵守 AdMob 政策
 
 📱 测试设备:
 将真实设备 ID 添加到 AdMobManager.swift 中的 testDeviceIDs 数组
 
 */
