import SwiftUI

struct AddMemberSheet: View {
    @Binding var isPresented: Bool
    @Binding var group: Group
    
    @State private var memberName = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Form {
                    Section("メンバーの名前") {
                        TextField("例: 山田太郎", text: $memberName)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("メンバーを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加") {
                        if !memberName.isEmpty {
                            group.addMember(memberName)
                            memberName = ""
                            isPresented = false
                        }
                    }
                    .disabled(memberName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let group = Group(name: "テスト", color: "#4FC3F7")
    AddMemberSheet(isPresented: .constant(true), group: .constant(group))
}
