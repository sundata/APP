import Foundation
import Combine

// MARK: - ユーザーアカウント管理
@MainActor
class UserManager: ObservableObject {
    static let shared = UserManager()
    
    @Published var userId: String = ""
    @Published var authToken: String = ""
    @Published var isAuthenticated = false
    
    private let userIdKey = "user_id"
    private let authTokenKey = "auth_token"
    
    private init() {
        loadOrCreateUser()
    }
    
    // MARK: - ユーザーID生成・読み込み
    private func loadOrCreateUser() {
        // 既存のユーザーIDを確認
        if let savedId = UserDefaults.standard.string(forKey: userIdKey),
           let savedToken = UserDefaults.standard.string(forKey: authTokenKey) {
            self.userId = savedId
            self.authToken = savedToken
            self.isAuthenticated = true
        } else {
            // 新規ユーザー作成
            createNewUser()
        }
    }
    
    private func createNewUser() {
        // UUID + タイムスタンプでユーザーIDを生成
        let uuid = UUID().uuidString
        let timestamp = String(Int(Date().timeIntervalSince1970))
        let newUserId = "user_\(timestamp)_\(uuid.prefix(8))"
        
        // アクセストークンを生成
        let newToken = generateAuthToken()
        
        self.userId = newUserId
        self.authToken = newToken
        
        // 保存
        UserDefaults.standard.set(newUserId, forKey: userIdKey)
        UserDefaults.standard.set(newToken, forKey: authTokenKey)
        
        self.isAuthenticated = true
        
        print("✅ 新規ユーザー作成: \(newUserId)")
    }
    
    // MARK: - 認可トークン生成
    private func generateAuthToken() -> String {
        // SHA256ハッシュベースのトークン生成（簡略版）
        let randomString = UUID().uuidString + String(Date().timeIntervalSince1970)
        return randomString.prefix(32).uppercased()
    }
    
    // MARK: - API用ヘッダー生成
    func getAuthHeaders() -> [String: String] {
        return [
            "Authorization": "Bearer \(authToken)",
            "X-User-ID": userId,
            "Content-Type": "application/json"
        ]
    }
}