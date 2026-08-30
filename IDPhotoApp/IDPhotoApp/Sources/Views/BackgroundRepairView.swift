import SwiftUI

struct BackgroundRepairView: View {
    @ObservedObject var viewModel: PhotoEditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var points: [CGPoint] = []
    @State private var restore = false
    @State private var brush: CGFloat = 0.035

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Picker("Mode", selection: $restore) {
                    Text("Erase background").tag(false)
                    Text("Restore subject").tag(true)
                }.pickerStyle(.segmented)
                GeometryReader { geo in
                    ZStack {
                        checkerboard
                        if let image = viewModel.backgroundRemovedImage { Image(uiImage: image).resizable().scaledToFit() }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onChanged { value in
                        let p = CGPoint(x: min(1, max(0, value.location.x / geo.size.width)), y: min(1, max(0, value.location.y / geo.size.height)))
                        points.append(p)
                        viewModel.repairBackground(points: [p], radius: brush, restore: restore)
                    })
                }
                HStack { Image(systemName: "circle"); Slider(value: $brush, in: 0.01...0.09); Image(systemName: "circle.fill") }
            }
            .padding()
            .navigationTitle("Edge repair")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var checkerboard: some View {
        Canvas { context, size in
            let cell: CGFloat = 14
            for y in stride(from: 0 as CGFloat, to: size.height, by: cell) {
                for x in stride(from: 0 as CGFloat, to: size.width, by: cell) {
                    context.fill(Path(CGRect(x: x, y: y, width: cell, height: cell)), with: .color((Int(x/cell)+Int(y/cell)).isMultiple(of: 2) ? .white : .gray.opacity(0.25)))
                }
            }
        }
    }
}
