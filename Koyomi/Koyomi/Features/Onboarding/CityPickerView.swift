import SwiftUI
import KoyomiCore

/// 位置情報を使わない場合の都市選択。
struct CityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (City) -> Void

    var body: some View {
        NavigationStack {
            List(City.selectable) { city in
                Button {
                    onSelect(city)
                } label: {
                    HStack {
                        Text(city.japaneseName)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .frame(minHeight: KoyomiTheme.minimumTapTarget)
                }
                .accessibilityIdentifier("city.\(city.id)")
            }
            .navigationTitle("都市を選ぶ")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }
}
