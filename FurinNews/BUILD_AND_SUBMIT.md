# App Store Connect チェックリスト＆ビルド準備

## ✅ Step 1: App Store Connect で IAP Product ID 確認

### 1.1 ログイン
- App Store Connect: https://appstoreconnect.apple.com
- Apple ID でログイン

### 1.2 アプリ内課金（In-App Purchases） 確認

**ナビゲーション：**
1. 「My Apps」をクリック
2. 「ニュースNow」を選択
3. 左メニュー → 「アプリ内課金」 or「In-App Purchases」

### 1.3 商品確認チェックリスト

以下の情報が正しく設定されていることを確認：

```
✅ 商品名（参照名）: Premium Lifetime または Advertise Removal
✅ Product ID: com.sundata.newsnow.premiumlifetime （重要！）
✅ 商品タイプ: 一度限りの購入 (Non-Consumable Purchase)
✅ 価格: ¥500
✅ ステータス: 承認済み（Approved）
✅ 国/地域: 日本が含まれている
```

### 1.4 価格設定の確認

```
ティア: Japan - ¥500
```

**もし商品がない場合は新規作成：**
1. 「+」ボタンをクリック
2. 製品タイプ: 「一度限りの購入」
3. Product ID: `com.sundata.newsnow.premiumlifetime`
4. 参照名: `Premium Lifetime`
5. 価格: Japan ¥500
6. 「保存」をクリック

### 1.5 Paid Apps Agreement の確認

**ナビゲーション：**
1. App Store Connect > 契約/税金/銀行口座
2. 「契約」タブ
3. 「Paid Apps Agreement」を確認

**ステータスを確認：**
```
✅ Status: 有効（Active）
✅ Last Modified: [最新日付]
```

**もしステータスが「保留中」または「署名不要」の場合：**
1. 「契約を確認」ボタンをクリック
2. 画面の指示に従い情報を入力
3. 法的条件に同意して署名

---

## ✅ Step 2: ビルド番号更新（完了）

### 確認

```
プロジェクトファイル: project.yml
CURRENT_PROJECT_VERSION: "3" ✅ 更新済み
MARKETING_VERSION: "1.0.0" ✅ 変更なし
```

**確認コマンド：**
```bash
grep -n "CURRENT_PROJECT_VERSION\|MARKETING_VERSION" /Users/sundata/WorkBuddy/20260412212940/FurinNews/project.yml
```

---

## ✅ Step 3: クリーンビルド実行

### 3.1 Xcode キャッシュをクリア

```bash
# プロジェクトディレクトリへ移動
cd /Users/sundata/WorkBuddy/20260412212940/FurinNews

# DerivedData をクリア
rm -rf ~/Library/Developer/Xcode/DerivedData/FurinNews*
rm -rf ~/Library/Developer/Xcode/DerivedData/*FurinNews*

# ビルドキャッシュをクリア
rm -rf build/
rm -rf dd/

# キャッシュをクリア
rm -rf .xcodeproj/xcuserdata
rm -rf .xcodeproj/project.xcworkspace/xcuserdata
```

### 3.2 プロジェクトの再生成（XcodeGen）

```bash
# XcodeGen で .xcodeproj を再生成
xcodegen generate
```

**出力例：**
```
✨ Generated FurinNews.xcodeproj
```

### 3.3 Xcode でクリーンビルド

```bash
# Xcode をコマンドラインから開く
open FurinNews.xcodeproj

# または、ターミナルから直接ビルド
xcodebuild clean -scheme FurinNews -configuration Release

# 再度ビルド
xcodebuild build -scheme FurinNews -configuration Release -derivedDataPath ./build
```

**Xcode GUI での方法：**
1. Xcode を開く：`open FurinNews.xcodeproj`
2. ⌘K（Cmd+K）キー または Product > Clean Build Folder
3. ⌘B（Cmd+B）キー または Product > Build

---

## ✅ 最終確認

実行後、以下をチェック：

```
✅ ビルド番号が「3」に更新されている
✅ エラーがなくビルディングが完了している
✅ App Store Connect IAP 商品が承認済み
✅ Paid Apps Agreement が有効
✅ StoreManager.swift の IAPProduct.premiumLifetime = "com.sundata.newsnow.premiumlifetime" が正しい
```

---

## 🚀 アップロード準備

ビルドが完了したら：

1. **Xcode Archive をエクスポート**
   - Product > Archive

2. **App Store Connect にアップロード**
   - Xcode から直接 "Upload to App Store"

3. **App Review Information を記入**
   - 「Previously rejected IAP issue - fixed」と記述

4. **提出**
   - Version 1.0 (Build 3) で提出

---

## トラブルシューティング

### ビルドエラーが出た場合

```bash
# 完全なクリーンアップ
cd /Users/sundata/WorkBuddy/20260412212940/FurinNews
rm -rf ~/Library/Developer/Xcode/DerivedData/* 
rm -rf build/ dd/
xcodegen generate
xcodebuild clean
xcodebuild build
```

### StoreKit エラーが出た場合

1. `IAPProduct.premiumLifetime` の値確認
2. 後部署 `com.sundata.newsnow.premiumlifetime` が正確か確認
3. App Store Connect の Product ID と完全に一致しているか確認

---

## 次のステップ

- [ ] App Store Connect で IAP Product ID 確認
- [ ] Paid Apps Agreement が有効か確認
- [ ] ビルド番号「3」に更新（✅ 完了）
- [ ] クリーンビルド実行
- [ ] Xcode から Archive → Upload
- [ ] App Review Information を記入
- [ ] 「Send」をクリックして再提出
