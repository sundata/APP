import Foundation

// グループ
struct Group: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var color: String // HEX color code
    var members: [Member] = []
    var payments: [Payment] = []
    var memo: String = ""
    var createdAt: Date = Date()
    
    mutating func addMember(_ name: String) {
        let member = Member(id: UUID(), name: name)
        members.append(member)
    }
    
    mutating func addPayment(payer: Member, amount: Double, description: String, date: Date = Date()) {
        let payment = Payment(
            id: UUID(),
            payerId: payer.id,
            amount: amount,
            description: description,
            date: date,
            splitAmong: members
        )
        payments.append(payment)
    }
    
    // 精算結果を計算
    var settlements: [Settlement] {
        calculateSettlements()
    }
    
    private func calculateSettlements() -> [Settlement] {
        var balances: [UUID: Double] = [:]
        
        // すべてのメンバーの初期バランスを0に設定
        for member in members {
            balances[member.id] = 0
        }
        
        // 支払いを処理
        for payment in payments {
            let splitAmount = payment.amount / Double(payment.splitAmong.count)
            
            // 支払者が追加（誰かに払われた）
            balances[payment.payerId, default: 0] += payment.amount
            
            // 分割対象者が減少（割り勘になる）
            for member in payment.splitAmong {
                balances[member.id, default: 0] -= splitAmount
            }
        }
        
        // 精算を生成
        var settlements: [Settlement] = []
        var positiveDebtors = balances.filter { $0.value > 0 }.sorted { $0.value > $1.value }
        var negativeDebtors = balances.filter { $0.value < 0 }.sorted { $0.value < $1.value }
        
        var pIndex = 0
        var nIndex = 0
        
        while pIndex < positiveDebtors.count && nIndex < negativeDebtors.count {
            let creditor = positiveDebtors[pIndex]
            let debtor = negativeDebtors[nIndex]
            
            let amount = min(creditor.value, -debtor.value)
            
            let creditorName = members.first(where: { $0.id == creditor.key })?.name ?? ""
            let debtorName = members.first(where: { $0.id == debtor.key })?.name ?? ""
            
            settlements.append(
                Settlement(
                    from: debtorName,
                    to: creditorName,
                    amount: amount
                )
            )
            
            positiveDebtors[pIndex].value -= amount
            negativeDebtors[nIndex].value += amount
            
            if positiveDebtors[pIndex].value == 0 {
                pIndex += 1
            }
            if negativeDebtors[nIndex].value == 0 {
                nIndex += 1
            }
        }
        
        return settlements
    }
}

// メンバー
struct Member: Identifiable, Codable {
    var id: UUID
    var name: String
}

// 支払い
struct Payment: Identifiable, Codable {
    var id: UUID
    var payerId: UUID
    var amount: Double
    var description: String
    var date: Date
    var splitAmong: [Member]
}

// 精算
struct Settlement: Identifiable {
    var id: UUID = UUID()
    var from: String
    var to: String
    var amount: Double
}
