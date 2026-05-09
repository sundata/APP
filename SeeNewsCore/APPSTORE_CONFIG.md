# App Store 課金設定ガイド

## StoreKit2 実装完了 ✅

このアプリはStoreKit2を使用した本格的なApp Store課金機能を実装しています。

---

## 環境構成

### 1. **Xcode 設定**

#### capabilities の有効化
- Target → Signing & Capabilities
- "+ Capability" をクリック
- **In-App Purchase** を追加

#### entitlements ファイル
ファイルは自動生成されます：
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.in-app-purchase</key>
    <true/>
</dict>
</plist>
```

---

## App Store Connect 設定

### 2. **アプリ登録**

1. [App Store Connect](https://appstoreconnect.apple.com) にログイン
2. My Apps → 新規アプリを追加
3. 以下を入力：
   - **App Name**: 3秒ニュース
   - **Bundle ID**: com.3secnews.app
   - **SKU**: 3SECNEWS-APP-001

### 3. **サブスクリプション設定**

**Subscription グループを作成**
- 名前: `com.3secnews.pro`
- 説明: Pro プラン

**サブスクリプション商品を 2 つ作成**

#### 月額プラン
- **Reference Name**: Pro Monthly
- **Product ID**: `com.3secnews.pro.monthly`
- **Price Tier**: JP11 (¥680 / 月)
- **Billing Cycle**: Monthly
- **Auto-Renewable Subscription**: ON

#### 年額プラン
- **Reference Name**: Pro Yearly
- **Product ID**: `com.3secnews.pro.yearly`
- **Price Tier**: JP108 (¥6,800 / 年)
- **Billing Cycle**: Annual
- **Auto-Renewable Subscription**: ON

### 4. **デバイスでのテスト**

#### Sandbox ユーザーを作成
1. Users and Access → Sandbox Testers
2. "+ " をクリック
3. Project テスター作成
4. メール、パスワードを入力

#### テストデバイスで実行
- Xcode から実機にインストール
- App Store Connect で作成した Sandbox ユーザーでログイン
- アプリ内で購入をテスト

---

## コード実装確認

### 課金フロー

```swift
// 1. 製品情報の自動読み込み
@Published var availableProducts: [Product] = []
// → PurchaseManager.setupPurchases() が自動実行

// 2. ユーザーが購入をクリック
Button { 
    Task {
        let success = await purchaseManager.purchase(product: product)
    }
}

// 3. Apple ID 認証ダイアログが表示
// ユーザーが Face ID / Touch ID で確認

// 4. トランザクション完了
// → handleVerifiedTransaction() が自動実行

// 5. バックエンドにレシート送信
// → verifyReceiptWithServer() が呼び出される
```

---

## バックエンド統合

### App Store Server API 検証

```
POST /subscription/verify-receipt
Header: Authorization: Bearer [authToken]
Header: X-User-ID: [userId]

Body: {
    "transactionID": "...",
    "productID": "com.3secnews.pro.monthly",
    "originalTransactionID": "....",
    "expirationDate": 1234567890,
    "purchaseDate": 1234567890
}
```

バックエンドでの検証方法：
1. Transaction ID を使用して [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi) でレシート検証
2. 有効期限を確認
3. ユーザーの Pro 状態を更新

---

## テスト用レシート

開発時は自動でテストレシートが生成されます：
- **Sandbox Environment** で実行時は、自動的にテスト用トランザクション
- 本番販売時は **Production** レシートに切り替え

---

## トラブルシューティング

| 問題 | 解決方法 |
|------|---------|
| 製品が表示されない | App Store Connect で商品を **Active** に設定 |
| 購入ボタンが反応しない | Sandbox テスターで実行 |
| レシート検証エラー | バックエンドのトークンを確認 |

---

## 今後の改善（オプション）

- [ ] 購入サブスクリプション管理画面
- [ ] サブスクリプション更新通知
- [ ] 無料トライアル期間の設定
- [ ] ファミリー共有対応
- [ ] クロスプラットフォーム同期
