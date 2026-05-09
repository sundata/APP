import SwiftUI
import UserNotifications

// MARK: - 設定・プロフィール画面
struct SettingsView: View {
    @AppStorage("autoRefreshEnabled") private var autoRefreshEnabled = true
    @AppStorage("refreshInterval") private var refreshInterval = 30
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("selectedAppearance") private var selectedAppearance = 0  // 0=auto, 1=light, 2=dark
    @AppStorage("textSizeIndex") private var textSizeIndex = 1  // 0=small,1=medium,2=large
    @EnvironmentObject var viewModel: NewsViewModel
    @State private var showingClearConfirm = false
    @State private var notificationStatus = "確認中..."
    
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
                
                // ── 通知 ──
                Section {
                    HStack {
                        Toggle("プッシュ通知", isOn: $notificationsEnabled)
                            .tint(.red)
                            .onChange(of: notificationsEnabled) { newValue in
                                if newValue {
                                    // 请求推送通知权限
                                    Task {
                                        let center = UNUserNotificationCenter.current()
                                        do {
                                            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                                            if !granted {
                                                notificationsEnabled = false
                                            } else {
                                                DispatchQueue.main.async {
                                                    UIApplication.shared.registerForRemoteNotifications()
                                                }
                                            }
                                        } catch {
                                            notificationsEnabled = false
                                        }
                                    }
                                } else {
                                    // 清除所有通知
                                    UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                                    UNUserNotificationCenter.current().removeAllDeliveredNotifications()
                                    UIApplication.shared.applicationIconBadgeNumber = 0
                                }
                            }
                    }
                    
                    if notificationsEnabled {
                        // 通知状態表示
                        HStack {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("有効")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
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
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    Link(destination: URL(string: "https://newsnow.app/privacy")!) {
                        Label("プライバシーポリシー", systemImage: "hand.raised.fill")
                    }
                    Link(destination: URL(string: "https://newsnow.app/terms")!) {
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
                    viewModel.clearCache()
                }
                Button("キャンセル", role: .cancel) {}
            }
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "ja_JP")
        fmt.dateFormat = "M月d日 HH:mm"
        return fmt.string(from: date)
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
