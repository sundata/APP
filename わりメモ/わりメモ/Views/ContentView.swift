import SwiftUI

struct ContentView: View {
    @EnvironmentObject var groupManager: GroupManager
    @State private var showNewGroupSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 背景
                Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 0.1))
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ヘッダー
                    VStack(alignment: .leading, spacing: 8) {
                        Text("わりメモ")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                        
                        Text("かんたん割り勘・旅行精算")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                    .padding(.bottom, 20)
                    
                    // グループリスト
                    if groupManager.groups.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            
                            VStack(spacing: 12) {
                                Image(systemName: "square.grid.2x2")
                                    .font(.system(size: 48))
                                    .foregroundColor(.gray)
                                
                                Text("グループを作成してはじめましょう")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.gray)
                                
                                Text("飲み会や旅行のグループを作成すると、\n簡単に割り勘の計算ができます")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 12) {
                                ForEach(groupManager.groups) { group in
                                    NavigationLink(destination: GroupDetailView(group: group)) {
                                        GroupRow(group: group)
                                    }
                                }
                                
                                Spacer(minLength: 100)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                        }
                    }
                    
                    Spacer()
                }
                
                // 追加ボタン
                VStack {
                    Spacer()
                    
                    HStack {
                        Spacer()
                        
                        Button(action: { showNewGroupSheet = true }) {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color(UIColor(red: 0.31, green: 0.77, blue: 0.97, alpha: 1)))
                                .clipShape(Circle())
                        }
                        .padding(20)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showNewGroupSheet) {
                NewGroupSheet(isPresented: $showNewGroupSheet)
                    .environmentObject(groupManager)
            }
        }
    }
}

struct GroupRow: View {
    let group: Group
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // グループカラーサークル
                Circle()
                    .fill(Color(hex: group.color))
                    .frame(width: 44, height: 44)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("メンバー: \(group.members.count)名")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
    }
}

#Preview {
    ContentView()
        .environmentObject(GroupManager())
}
