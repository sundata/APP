import Foundation

class GroupManager: ObservableObject {
    @Published var groups: [Group] = []
    
    private let groupsKey = "warimeao_groups"
    
    init() {
        loadGroups()
    }
    
    // グループ作成
    func createGroup(name: String, color: String, memo: String = "") {
        var newGroup = Group(
            id: UUID(),
            name: name,
            color: color,
            memo: memo
        )
        groups.append(newGroup)
        saveGroups()
    }
    
    // グループ削除
    func deleteGroup(at offsets: IndexSet) {
        groups.remove(atOffsets: offsets)
        saveGroups()
    }
    
    // グループ更新
    func updateGroup(_ group: Group) {
        if let index = groups.firstIndex(where: { $0.id == group.id }) {
            groups[index] = group
            saveGroups()
        }
    }
    
    // グループ取得
    func getGroup(by id: UUID) -> Group? {
        return groups.first(where: { $0.id == id })
    }
    
    // 保存
    private func saveGroups() {
        do {
            let encoded = try JSONEncoder().encode(groups)
            UserDefaults.standard.set(encoded, forKey: groupsKey)
        } catch {
            print("[GroupManager] グループ保存に失敗: \(error)")
        }
    }
    
    // 読み込み
    private func loadGroups() {
        guard let data = UserDefaults.standard.data(forKey: groupsKey) else { return }
        do {
            groups = try JSONDecoder().decode([Group].self, from: data)
        } catch {
            print("[GroupManager] グループ読み込みに失敗: \(error)")
        }
    }
}
