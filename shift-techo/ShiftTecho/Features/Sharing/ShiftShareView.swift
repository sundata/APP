import SwiftUI
import UIKit
import ShiftTechoCore

/// 共有画像のプレビューと書き出し。給与・メモ・広告は一切含めない。
@MainActor
struct ShiftShareView: View {
    @Environment(\.dismiss) private var dismiss

    private let content: ShiftShareContent

    @State private var exportedURL: URL?
    @State private var exportErrorMessage: String?
    @State private var isExporting = false
    @State private var exportedImage: UIImage?

    init(month: CalendarMonth, assignments: [String: ShiftAssignment], holidays: [String: String]) {
        content = ShiftShareContent(month: month, assignments: assignments, holidays: holidays)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ShiftTechoTheme.Spacing.m) {
                    if content.isEmpty {
                        Text("この月にはシフトがありません。空のカレンダーを共有します。")
                            .font(ShiftTechoTheme.captionFont)
                            .foregroundStyle(ShiftTechoTheme.sunday)
                            .accessibilityIdentifier("shareEmptyWarning")
                    }

                    ShiftSharePosterView(content: content)
                        .scaleEffect(0.3, anchor: .topLeading)
                        .frame(
                            width: ShiftShareContent.imageSize.width * 0.3,
                            height: ShiftShareContent.imageSize.height * 0.3,
                            alignment: .topLeading
                        )
                        .clipped()
                        .accessibilityIdentifier("sharePreview")
                        .accessibilityLabel("共有画像のプレビュー。給与とメモは含まれません。")

                    Text("画像には時給・予想給与・メモは含まれません。")
                        .font(ShiftTechoTheme.captionFont)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("shareNoticeText")

                    if let url = exportedURL {
                        if let exportedImage {
                            Image(uiImage: exportedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .accessibilityLabel("作成した共有画像")
                        }
                        ShareLink(item: url) {
                            Text("画像を共有")
                                .font(ShiftTechoTheme.bodyFont.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: ShiftTechoTheme.minimumTapTarget)
                        }
                        .accessibilityIdentifier("shareSheetButton")
                    } else {
                        ShiftTechoPrimaryButton(title: isExporting ? "作成中…" : "画像を作成") { export() }
                            .disabled(isExporting)
                            .accessibilityIdentifier("shareRenderButton")
                    }
                }
                .padding(ShiftTechoTheme.Spacing.m)
            }
            .navigationTitle("シフトを共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .alert("画像を作成できませんでした", isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { exportErrorMessage = nil }
            } message: {
                Text(exportErrorMessage ?? "もう一度お試しください。")
            }
        }
    }

    @MainActor
    private func export() {
        isExporting = true
        exportErrorMessage = nil
        defer { isExporting = false }

        let size = CGSize(
            width: ShiftShareContent.imageSize.width,
            height: ShiftShareContent.imageSize.height
        )
        let renderer = ImageRenderer(content:
            ShiftSharePosterView(content: content)
                .environment(\.colorScheme, .light)
                .frame(width: size.width, height: size.height)
        )
        renderer.proposedSize = ProposedViewSize(size)
        renderer.scale = 1
        // ImageRenderer 自身に UIImage を生成させることで、Core Graphics と UIKit の
        // Y 軸方向の違いによる上下反転を避ける。
        guard let image = renderer.uiImage,
              image.size == size,
              let data = image.pngData(), !data.isEmpty else {
            exportErrorMessage = "PNGデータへの変換に失敗しました。"
            return
        }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("shifttecho-\(content.title).png")
        do {
            try data.write(to: url, options: .atomic)
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw CocoaError(.fileNoSuchFile)
            }
            exportedImage = image
            exportedURL = url
        } catch {
            exportErrorMessage = "画像ファイルを保存できませんでした。空き容量を確認してください。"
        }
    }
}

/// 1080 × 1350 の縦長ポスター。数値やレイアウトは実寸を前提にしている。
struct ShiftSharePosterView: View {
    let content: ShiftShareContent

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(content.title)
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(ShiftTechoTheme.ink)

            HStack(spacing: 6) {
                ForEach(Array(content.weekdaySymbols.enumerated()), id: \.offset) { index, symbol in
                    Text(symbol)
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(weekdayColor(index + 1))
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 7), spacing: 6) {
                ForEach(content.cells) { cell in
                    PosterCell(cell: cell)
                }
            }

            if !content.legend.isEmpty {
                HStack(spacing: 24) {
                    ForEach(Array(content.legend.enumerated()), id: \.offset) { _, item in
                        HStack(spacing: 10) {
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(ShiftTechoTheme.color(item.color))
                                .frame(width: 28, height: 28)
                            Text(item.label)
                                .font(.system(size: 30))
                                .foregroundStyle(ShiftTechoTheme.ink)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(content.brandName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(ShiftTechoTheme.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(56)
        .frame(width: ShiftShareContent.imageSize.width, height: ShiftShareContent.imageSize.height)
        .background(ShiftTechoTheme.washi)
    }

    private func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: ShiftTechoTheme.sunday
        case 7: ShiftTechoTheme.saturday
        default: ShiftTechoTheme.ink
        }
    }
}

private struct PosterCell: View {
    let cell: ShiftShareCell

    var body: some View {
        VStack(spacing: 6) {
            if let day = cell.day {
                Text("\(day)")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(numberColor)
                if let label = cell.label, let color = cell.color {
                    Text(label)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 6)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(ShiftTechoTheme.color(color)))
                } else {
                    Text("－")
                        .font(.system(size: 24))
                        .foregroundStyle(ShiftTechoTheme.ink.opacity(0.35))
                }
            }
            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(height: 136)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(cell.isPlaceholder ? Color.clear : Color.white)
        )
    }

    private var numberColor: Color {
        if cell.holidayName != nil || cell.weekday == 1 { return ShiftTechoTheme.sunday }
        if cell.weekday == 7 { return ShiftTechoTheme.saturday }
        return ShiftTechoTheme.ink
    }
}
