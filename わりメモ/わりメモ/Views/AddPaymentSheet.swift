import SwiftUI

struct AddPaymentSheet: View {
    @Binding var isPresented: Bool
    @Binding var group: Group
    
    @State private var selectedPayer: Member?
    @State private var amount = ""
    @State private var description = ""
    @State private var date = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("誰が払いましたか？") {
                    Picker("支払者", selection: $selectedPayer) {
                        Text("選択してください").tag(nil as Member?)
                        ForEach(group.members) { member in
                            Text(member.name).tag(member as Member?)
                        }
                    }
                }
                
                Section("金額") {
                    HStack {
                        Text("¥")
                        TextField("金額を入力", text: $amount)
                            .keyboardType(.numberPad)
                    }
                }
                
                Section("内容") {
                    TextField("例: 居酒屋、ホテル", text: $description)
                }
                
                Section("日付") {
                    DatePicker("日付", selection: $date, displayedComponents: .date)
                }
            }
            .navigationTitle("支払いを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("キャンセル") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("追加") {
                        if let payer = selectedPayer,
                           let amountValue = Double(amount),
                           !description.isEmpty {
                            group.addPayment(
                                payer: payer,
                                amount: amountValue,
                                description: description,
                                date: date
                            )
                            isPresented = false
                        }
                    }
                    .disabled(selectedPayer == nil || amount.isEmpty || description.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let group = Group(name: "テスト", color: "#4FC3F7", members: [
        Member(id: UUID(), name: "山田"),
        Member(id: UUID(), name: "佐藤")
    ])
    
    AddPaymentSheet(isPresented: .constant(true), group: .constant(group))
}
