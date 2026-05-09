import Foundation

// MARK: - アプリ設定（有料版への誘導など）
enum AppConfig {
    ///  有料版 App Store URL
    static let paidAppStoreURL = "https://apps.apple.com/jp/app/%E8%A8%BC%E6%98%8E%E5%86%99%E7%9C%9F-id-photo-maker/id6760736426"

    ///  有料版 App ID（App Store で開く用）
    static let paidAppID = "6760736426"

    /// アプリが無料版かどうか
    static let isFreeVersion = true

    /// 無料で使用可能なサイズ数の上限
    static let maxFreeSizes = 10

    /// 無料で使用可能な Popular Sizes
    static let freePopularSizeIDs = ["passport_jp", "license_jp", "mynumber", "resume_l", "resume_s"]
}

// MARK: - バージョン管理
extension AppConfig {
    static var appName: String {
        isFreeVersion ? "パシャっと証明写真" : "証明写真"
    }

    static var appNameWithVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "\(appName) v\(version)"
    }
}
