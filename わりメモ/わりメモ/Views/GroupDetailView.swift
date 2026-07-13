import SwiftUI

struct GroupDetailView: View {
    @EnvironmentObject var groupManager: GroupManager
    @Environment(\.dismiss) var dismiss
    
    var group: Group
    @State private var localGroup: Group
    @State private var showAddPaymentSheet = false
    @State private var showAddMemberSheet = false
    
    init(group: Group) {
        self.group = group
        _localGroup = State(initialValue: group)
    }
    
    var totalAmount: Double {
        localGroup.payments.reduce(0) { $0 + $1.amount }
    }
    
    var body: some View {
        ZStack {
            Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.1))
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: localGroup.color))
                        .frame(width: 48, height: 48)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(localGroup.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("合計: ¥\(Int(totalAmount)):,000")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.white)
                .border(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.2)), width: 1)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // メンバーセクション
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("メンバー (\(localGroup.members.count)名)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Button(action: { showAddMemberSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                                }
                            }
                            
                            if localGroup.members.isEmpty {
                                Text("メンバーをまず追加してください")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(localGroup.members) { member in
                                        HStack {
                                            Text(member.name)
                                                .font(.system(size: 14))
                                                .foregroundColor(.black)
                                            
                                            Spacer()
                                        }
                                        .padding(12)
                                        .background(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.1)))
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        // 支払い履歴セクション
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("支払い履歴")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Button(action: { showAddPaymentSheet = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundColor(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                                }
                            }
                            
                            if localGroup.payments.isEmpty {
                                Text("支払いはまだありません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.vertical, 20)
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(localGroup.payments.sorted { $0.date > $1.date }) { payment in
                                        if let payer = localGroup.members.first(where: { $0.id == payment.payerId }) {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text(payer.name)
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(.black)
                                                    
                                                    Spacer()
                                                    
                                                    Text("¥\(Int(payment.amount)):,000")
                                                        .font(.system(size: 14, weight: .semibold))
                                                        .foregroundColor(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                                                }
                                                
                                                Text(payment.description)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(.gray)
                                            }
                                            .padding(12)
                                            .background(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.1)))
                                            .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        
                        // 精算結果セクション
                        SettlementResultView(settlements: localGroup.settlements)
                        
                        Spacer(minLength: 100)
                    }
                    .padding(16)
                }
            }
        }
        .navigationBarBackButtonHidden(false)
        .onDisappear {
            groupManager.updateGroup(localGroup)
        }
        .sheet(isPresented: $showAddPaymentSheet) {
            AddPaymentSheet(
                isPresented: $showAddPaymentSheet,
                group: $localGroup
            )
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberSheet(
                isPresented: $showAddMemberSheet,
                group: $localGroup
            )
        }
    }
}

#Preview {
    let group = Group(name: "沖縄旅行", color: "#4FC3F7")
    NavigationStack {
        GroupDetailView(group: group)
            .environmentObject(GroupManager())
    }
}
