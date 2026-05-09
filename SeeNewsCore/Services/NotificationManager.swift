import Foundation
import UserNotifications
import Combine

// MARK: - 通知マネージャー
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    
    @Published var isNotificationsEnabled = false
    @Published var notificationSettings: UNNotificationSettings?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await checkNotificationAuthorization() }
    }
    
    // MARK: - 通知権限の要求
    @MainActor
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            await checkNotificationAuthorization()
            return granted
        } catch {
            print("❌ 通知権限の要求に失敗: \(error)")
            return false
        }
    }
    
    // MARK: - 通知権限の確認
    @MainActor
    private func checkNotificationAuthorization() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        self.notificationSettings = settings
        self.isNotificationsEnabled = settings.authorizationStatus == .authorized
    }
    
    // MARK: - 新しいニュース通知を送信
    func sendNewsNotification(
        title: String,
        summary: String,
        category: String,
        articleID: String,
        imageURL: URL? = nil
    ) async {
        guard isNotificationsEnabled else {
            print("⚠️ 通知が有効になっていません")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = summary
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        
        // カテゴリの設定
        content.categoryIdentifier = "NEWS_NOTIFICATION"
        content.userInfo = [
            "articleID": articleID,
            "category": category,
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 画像の添付（オプション）
        if let imageURL = imageURL {
            do {
                let imageData = try Data(contentsOf: imageURL)
                if let image = UIImage(data: imageData) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("notification_image_\(articleID).jpg")
                    try image.jpegData(compressionQuality: 0.8)?.write(to: tempURL)
                    
                    if let attachment = try? UNNotificationAttachment(identifier: "image", url: tempURL) {
                        content.attachments = [attachment]
                    }
                }
            } catch {
                print("⚠️ 画像の処理に失敗: \(error)")
            }
        }
        
        // 通知をスケジュール（5秒後）
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "news_\(articleID)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 通知をスケジュール: \(title)")
        } catch {
            print("❌ 通知のスケジュールに失敗: \(error)")
        }
    }
    
    // MARK: - Pro専用機能の通知
    func sendProFeatureNotification() async {
        guard isNotificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "今ならProプランが30%OFF"
        content.body = "AI分析が使い放題。広告なしでニュースを楽しもう"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = "SUBSCRIPTION_PROMOTION"
        content.userInfo = ["type": "pro_promo"]
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: "pro_promotion",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("⚠️ Proプロモーション通知の送信に失敗: \(error)")
        }
    }
    
    // MARK: - カテゴリ別の定期通知（バックグラウンド）
    func schedulePeriodicCategoryNotification(
        category: String,
        articleCount: Int
    ) async {
        guard isNotificationsEnabled else { return }
        
        let categoryName: String
        switch category {
        case "celebrity":
            categoryName = "芸能"
        case "sports":
            categoryName = "スポーツ"
        case "politician":
            categoryName = "政治"
        case "business":
            categoryName = "ビジネス"
        case "overseas":
            categoryName = "海外"
        default:
            categoryName = "ニュース"
        }
        
        let content = UNMutableNotificationContent()
        content.title = "\(categoryName)ニュース \(articleCount)件"
        content.body = "最新の\(categoryName)情報をチェック"
        content.sound = .default
        content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = "CATEGORY_UPDATE"
        content.userInfo = [
            "category": category,
            "count": articleCount
        ]
        
        // 毎日午前8時に通知
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: "daily_\(category)",
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 定期通知をスケジュール: \(categoryName)")
        } catch {
            print("⚠️ 定期通知のスケジュールに失敗: \(error)")
        }
    }
    
    // MARK: - 全通知をキャンセル
    func cancelAllNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    // MARK: - フォアグラウンド通知の処理
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        print("📲 フォアグラウンド通知を受信: \(notification.request.content.title)")
        
        // アプリがアクティブな状態でも通知を表示
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - 通知の追跡（タップされた時）
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        
        if let articleID = userInfo["articleID"] as? String {
            print("📖 ユーザーがニュース通知をタップ: \(articleID)")
            // アプリ内で記事を開く処理
            NotificationCenter.default.post(
                name: NSNotification.Name("OpenArticle"),
                object: nil,
                userInfo: ["articleID": articleID]
            )
        } else if let type = userInfo["type"] as? String, type == "pro_promo" {
            print("🎁 ユーザーがProプロモーション通知をタップ")
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowSubscriptionSheet"),
                object: nil
            )
        }
        
        completionHandler()
    }
}

// MARK: - Global notification helpers
extension NSNotification.Name {
    static let openArticle = NSNotification.Name("OpenArticle")
    static let showSubscriptionSheet = NSNotification.Name("ShowSubscriptionSheet")
}
