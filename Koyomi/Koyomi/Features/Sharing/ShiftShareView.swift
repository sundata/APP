import SwiftUI
import UIKit
import KoyomiCore

/// 共有画像のプレビューと書き出し。給与・メモ・広告は一切含めない。
@MainActor
struct ShiftShareView: View {
    @Environment(\.dismiss) private var dismiss

    private let content: ShiftShareContent

    @State private var exportedURL: URL?

    init(month: CalendarMonth, assignments: [String: ShiftAssignment], holidays: [String: String]) {
        content = ShiftShareContent(month: month, assignments: assignments, holidays: holidays)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: KoyomiTheme.Spacing.m) {
                    if content.isEmpty {
                        Text("この月にはシフトがありません。空のカレンダーを共有します。")
                            .font(KoyomiTheme.captionFont)
                            .foregroundStyle(KoyomiTheme.sunday)
                            .accessibilityIdentifier("shareEmptyWarning")
                    }

                    ShiftSharePosterView(content: content)
                        .scaleEffect(0.3, anchor: .topLeading)
                        .frame(
                            width: ShiftShareContent.imageSize.width * 0.3,
                            height: ShiftShareContent.imageSize.height * 0.3
                        )
                        .accessibilityIdentifier("sharePreview")
                        .accessibilityLabel("共有画像のプレビュー。給与とメモは含まれません。")

                    Text("画像には時給・予想給与・メモは含まれません。")
                        .font(KoyomiTheme.captionFont)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("shareNoticeText")

                    if let url = exportedURL {
                        ShareLink(item: url) {
                            Text("画像を共有")
                                .font(KoyomiTheme.bodyFont.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: KoyomiTheme.minimumTapTarget)
                        }
                        .accessibilityIdentifier("shareSheetButton")
                    } else {
                        KoyomiPrimaryButton(title: "画像を作成") { export() }
                            .accessibilityIdentifier("shareRenderButton")
                    }
                }
                .padding(KoyomiTheme.Spacing.m)
            }
            .navigationTitle("シフトを共有")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func export() {
        let renderer = ImageRenderer(content: ShiftSharePosterView(content: content))
        renderer.proposedSize = ProposedViewSize(
            width: ShiftShareContent.imageSize.width,
            height: ShiftShareContent.imageSize.height
        )
        renderer.scale = 1
        guard let image = renderer.uiImage, let data = image.pngData() else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("koyomi-\(content.title).png")
        try? data.write(to: url, options: .atomic)
        exportedURL = url
    }
}

/// 1080 × 1350 の縦長ポスター。数値やレイアウトは実寸を前提にしている。
struct ShiftSharePosterView: View {
    let content: ShiftShareContent

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text(content.title)
                .font(.system(size: 76, weight: .bold))
                .foregroundStyle(KoyomiTheme.ink)

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
                                .fill(KoyomiTheme.color(item.color))
                                .frame(width: 28, height: 28)
                            Text(item.label)
                                .font(.system(size: 30))
                                .foregroundStyle(KoyomiTheme.ink)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Text(content.brandName)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(KoyomiTheme.ink.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(56)
        .frame(width: ShiftShareContent.imageSize.width, height: ShiftShareContent.imageSize.height)
        .background(KoyomiTheme.washi)
    }

    private func weekdayColor(_ weekday: Int) -> Color {
        switch weekday {
        case 1: KoyomiTheme.sunday
        case 7: KoyomiTheme.saturday
        default: KoyomiTheme.ink
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
                        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(KoyomiTheme.color(color)))
                } else {
                    Text("－")
                        .font(.system(size: 24))
                        .foregroundStyle(KoyomiTheme.ink.opacity(0.35))
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
        if cell.holidayName != nil || cell.weekday == 1 { return KoyomiTheme.sunday }
        if cell.weekday == 7 { return KoyomiTheme.saturday }
        return KoyomiTheme.ink
    }
}
