import SwiftUI

// MARK: - 有料版へのアップグレード画面
struct ProUpgradeView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // アイコン
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                }

                // タイトル
                Text("有料版にアップグレード")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                // 説明
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "star.fill",                 text: "全てのサイズが無制限に使用可能")
                    FeatureRow(icon: "photo.stack.fill",          text: "複数サイズを一度に作成")
                    FeatureRow(icon: "square.and.arrow.up.fill",  text: "高解像度書き出し（600 DPI）")
                    FeatureRow(icon: "nosign",                    text: "広告なし")
                }
                .padding(.horizontal, 24)

                Spacer()

                // App Store ボタン
                Button {
                    openAppStore()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("App Store で見る")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "007AFF"), Color(hex: "5856D6")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .padding(.horizontal, 24)

                // 閉じるボタン
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private func openAppStore() {
        if let url = URL(string: AppConfig.paidAppStoreURL) {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - 機能リスト行
struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.orange)
                .frame(width: 24)

            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)

            Spacer()
        }
    }
}

#Preview {
    ProUpgradeView()
}
