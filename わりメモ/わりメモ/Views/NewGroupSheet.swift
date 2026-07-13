import SwiftUI

struct NewGroupSheet: View {
    @EnvironmentObject var groupManager: GroupManager
    @Binding var isPresented: Bool
    
    @State private var groupName = ""
    @State private var selectedColor = "#4FC3F7"
    @State private var memo = ""
    
    let colors = [
        "#4FC3F7", // 水色
        "#81D4FA", // 淡ブルー
        "#FFFFFF", // 白
        "#43A047", // 緑
        "#FFB300"  // オレンジ
    ]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("グループ名") {
                    TextField("例: 沖縄旅行", text: $groupName)
                }
                
                Section("アイコン色") {
                    HStack(spacing: 12) {
                        ForEach(colors, id: \.self) { color in
                            Button(action: { selectedColor = color }) {
                                Circle()
                                    .fill(Color(hex: color))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        selectedColor == color ?
                                        Circle()
                                            .stroke(Color.blue, lineWidth: 3) :
                                        nil
                                    )
                            }
                        }
                        Spacer()
                    }
                }
                
                Section("メモ") {
                    TextEditor(text: $memo)
                        .frame(height: 80)
                }
            }
            .navigationTitle("新しいグループ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("作成") {
                        if !groupName.isEmpty {
                            groupManager.createGroup(
                                name: groupName,
                                color: selectedColor,
                                memo: memo
                            )
                            isPresented = false
                        }
                    }
                    .disabled(groupName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NewGroupSheet(isPresented: .constant(true))
        .environmentObject(GroupManager())
}
