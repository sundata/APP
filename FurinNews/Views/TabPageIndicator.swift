import SwiftUI

// MARK: - タブページインジケーター
/// TabView用のページ位置インジケーター
struct TabPageIndicator: View {
    let categories: [NewsCategory]
    let selected: NewsCategory
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(categories, id: \.self) { category in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        selected == category
                            ? Color.red.opacity(0.8)
                            : Color.gray.opacity(0.3)
                    )
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: selected)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    VStack {
        TabPageIndicator(
            categories: NewsCategory.allCases,
            selected: .trending
        )
        Spacer()
    }
    .padding()
}
