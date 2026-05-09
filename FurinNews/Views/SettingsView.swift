import SwiftUI

// MARK: - 設定・プロフィール画面
struct SettingsView: View {
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("selectedAppearance") private var selectedAppearance = 0  // 0=auto, 1=light, 2=dark
    @AppStorage("textSizeIndex") private var textSizeIndex = 1  // 0=small,1=medium,2=large
    @EnvironmentObject var viewModel: NewsViewModel
    @ObservedObject private var storeManager = StoreManager.shared
    @State private var showingClearConfirm = false
    @State private var showingPaywall = false
    
    let intervals = [15, 30, 60]
    let appearanceOptions = ["自動", "ライト", "ダーク"]
    let textSizeOptions = ["小", "中", "大"]
    
    var body: some View {
        NavigationStack {
            List {
                // ── 更新設定 ──
                Section {
                    Toggle("自動更新", isOn: $autoRefreshEnabled)
                        .tint(.red)
                    
                    if autoRefreshEnabled {
                        Picker("更新間隔", selection: $refreshInterval) {
                            ForEach(intervals, id: \.self) { min in
                                Text("\(min)分ごと").tag(min)
                            }
                        }
                    }
                } header: {
                    Label("更新設定", systemImage: "arrow.clockwise")
                }

                // ── プレミアム ──
                Section {
                    if storeManager.isPremiumUser {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                            Text("プレミアム有効")
                                .font(FontScaler.font(size: 15, weight: .medium))
                                .foregroundColor(.green)
                            Spacer()
                            Text("広告なし")
                                .font(FontScaler.caption())
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Button {
                            showingPaywall = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "nosign")
                                    .font(FontScaler.font(size: 16, weight: .bold))
                                Text("広告を削除")
                                    .font(FontScaler.font(size: 16, weight: .bold))
                                Spacer()
                                Text("¥500")
                                    .font(FontScaler.font(size: 15, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.white.opacity(0.22))
                                    .clipShape(Capsule())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    Label("プレミアム", systemImage: "crown.fill")
                }

                // ── 通知 ──
                Section {
                    Toggle("プッシュ通知", isOn: $notificationsEnabled)
                        .tint(.red)
                    if notificationsEnabled {
                        NavigationLink {
                            NotificationSettingsView()
                        } label: {
                            Text("通知カテゴリを設定")
                        }
                    }
                } header: {
                    Label("通知", systemImage: "bell.fill")
                }
                
                // ── 表示 ──
                Section {
                    Picker("テーマ", selection: $selectedAppearance) {
                        ForEach(0..<appearanceOptions.count, id: \.self) {
                            Text(appearanceOptions[$0]).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Picker("文字サイズ", selection: $textSizeIndex) {
                        ForEach(0..<textSizeOptions.count, id: \.self) {
                            Text(textSizeOptions[$0]).tag($0)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("表示", systemImage: "paintbrush.fill")
                }
                
                // ── データ ──
                Section {
                    HStack {
                        Text("最終更新")
                        Spacer()
                        if let date = viewModel.lastUpdated {
                            Text(formattedDate(date))
                                .foregroundColor(.secondary)
                        } else {
                            Text("未取得").foregroundColor(.secondary)
                        }
                    }
                    
                    Button(role: .destructive) {
                        showingClearConfirm = true
                    } label: {
                        Label("キャッシュをクリア", systemImage: "trash")
                    }
                } header: {
                    Label("データ管理", systemImage: "internaldrive")
                }
                
                // ── アプリ情報 ──
                Section {
                    HStack {
                        Text("バージョン")
                        Spacer()
                        Text(appVersionText).foregroundColor(.secondary)
                    }
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                    }
                    NavigationLink {
                        TermsOfUseView()
                    } label: {
                        Label("利用規約", systemImage: "doc.text.fill")
                    }
                } header: {
                    Label("アプリについて", systemImage: "info.circle.fill")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "キャッシュをクリアしますか？",
                isPresented: $showingClearConfirm,
                titleVisibility: .visible
            ) {
                Button("クリア", role: .destructive) {
                    NewsCache().clear()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日 HH:mm"
        return fmt.string(from: date)
    }

    private var appVersionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
}

// MARK: - プライバシーポリシー
struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PolicySection(
                    title: "収集する情報",
                    text: "ニュースNowは、記事の表示、広告配信、アプリ内課金、クラッシュ解析のために必要な情報を利用します。個人を直接特定する情報をアプリ独自に収集することはありません。"
                )
                PolicySection(
                    title: "広告",
                    text: "本アプリはGoogle Mobile Adsを使用して広告を表示します。広告配信のため、Googleがデバイス情報や広告識別子を利用する場合があります。"
                )
                PolicySection(
                    title: "アプリ内課金",
                    text: "広告削除の購入処理はApple StoreKitを通じて行われます。決済情報はAppleによって処理され、アプリ側でクレジットカード情報を取得することはありません。"
                )
                PolicySection(
                    title: "お問い合わせ",
                    text: "本ポリシーに関するお問い合わせは、App Store Connectに登録されているサポート連絡先までお願いします。"
                )
            }
            .padding(20)
        }
        .navigationTitle("プライバシーポリシー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 利用規約
struct TermsOfUseView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PolicySection(
                    title: "サービス内容",
                    text: "ニュースNowは、インターネット上で公開されているニュース記事へのリンクと概要を表示するニュース閲覧アプリです。記事本文や外部サイトの内容については各提供元が責任を負います。"
                )
                PolicySection(
                    title: "アプリ内課金",
                    text: "広告削除は一度きりの購入です。購入後は、同じApple IDで利用する端末において購入を復元できます。"
                )
                PolicySection(
                    title: "禁止事項",
                    text: "本アプリの不正利用、リバースエンジニアリング、外部サービスへの過度なアクセス、第三者の権利を侵害する行為を禁止します。"
                )
                PolicySection(
                    title: "免責事項",
                    text: "本アプリはニュース情報の正確性、完全性、継続的な提供を保証しません。利用により発生した損害について、法令で認められる範囲で責任を負いません。"
                )
            }
            .padding(20)
        }
        .navigationTitle("利用規約")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PolicySection: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(FontScaler.font(size: 17, weight: .bold))
            Text(text)
                .font(FontScaler.subheadline())
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - 通知カテゴリ設定
struct NotificationSettingsView: View {
    @AppStorage("notif_celebrity") private var celebrity = true
    @AppStorage("notif_politician") private var politician = true
    @AppStorage("notif_sports") private var sports = false
    @AppStorage("notif_business") private var business = false
    @AppStorage("notif_overseas") private var overseas = false
    @AppStorage("notif_trending") private var trending = true
    
    var body: some View {
        List {
            ForEach(NewsCategory.allCases, id: \.self) { cat in
                Toggle(isOn: bindingForCategory(cat)) {
                    Label(cat.displayName, systemImage: cat.icon)
                }
                .tint(.red)
            }
        }
        .navigationTitle("通知カテゴリ")
    }
    
    private func bindingForCategory(_ cat: NewsCategory) -> Binding<Bool> {
        switch cat {
        case .celebrity:  return $celebrity
        case .politician: return $politician
        case .sports:     return $sports
        case .business:   return $business
        case .overseas:   return $overseas
        case .trending:   return $trending
        case .general:    return .constant(true)
        }
    }
}
