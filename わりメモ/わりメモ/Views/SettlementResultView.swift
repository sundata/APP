import SwiftUI

struct SettlementResultView: View {
    let settlements: [Settlement]
    @State private var shareText = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("精算結果")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
            
            if settlements.isEmpty {
                Text("精算が必要ありません")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    ForEach(settlements) { settlement in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(settlement.from)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Text("→ \(settlement.to)へ")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Text("¥\(Int(settlement.amount)):,000")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                        }
                        .padding(12)
                        .background(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.1)))
                        .cornerRadius(8)
                    }
                }
                
                // 共有ボタン
                HStack(spacing: 12) {
                    Spacer()
                    
                    Button(action: { shareViaLine() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                            Text("LINEで共有")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                        .cornerRadius(8)
                    }
                    
                    Button(action: { copyToClipboard() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.on.doc")
                            Text("コピー")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.1)))
                        .cornerRadius(8)
                    }
                    
                    Spacer()
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func shareViaLine() {
        let message = generateShareMessage()
        
        if let url = URL(string: "line://msg/text/\(message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") {
            if UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
            } else {
                UIPasteboard.general.string = message
            }
        }
    }
    
    private func copyToClipboard() {
        let message = generateShareMessage()
        UIPasteboard.general.string = message
    }
    
    private func generateShareMessage() -> String {
        var message = "【精算結果】\n\n"
        for settlement in settlements {
            message += "\(settlement.from) → \(settlement.to)\n¥\(Int(settlement.amount)):,000\n\n"
        }
        return message
    }
}

#Preview {
    let settlements = [
        Settlement(from: "田中", to: "山田", amount: 4000),
        Settlement(from: "佐藤", to: "山田", amount: 4000)
    ]
    SettlementResultView(settlements: settlements)
}
