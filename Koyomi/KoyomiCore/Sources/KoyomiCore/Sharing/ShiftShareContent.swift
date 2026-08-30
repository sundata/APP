import Foundation

/// 共有画像に載せる 1 マス分の情報。給与・メモは構造として持てないようにしている。
public struct ShiftShareCell: Identifiable, Hashable, Sendable {
    public let id: String
    public let day: Int?
    public let weekday: Int
    /// 勤務や休みの短い表記。未設定日は nil。
    public let label: String?
    public let color: ShiftColor?
    public let isRest: Bool
    public let holidayName: String?

    public var isPlaceholder: Bool { day == nil }
}

/// 共有画像の内容。年月・カレンダー・凡例・ブランド名だけを含む。
public struct ShiftShareContent: Sendable {
    /// 書き出しサイズ（縦長 1080 × 1350）。
    public static let imageSize = (width: 1080.0, height: 1350.0)

    public let title: String
    public let weekdaySymbols: [String]
    public let cells: [ShiftShareCell]
    /// 凡例（表示名と色）。使われているシフトだけを並べる。
    public let legend: [(label: String, color: ShiftColor, isRest: Bool)]
    public let brandName = "Koyomi"

    /// シフトが 1 件もない月かどうか。共有前の注意表示に使う。
    public var isEmpty: Bool {
        cells.allSatisfy { $0.label == nil }
    }

    public init(
        month: CalendarMonth,
        assignments: [String: ShiftAssignment],
        holidays: [String: String] = [:]
    ) {
        title = month.title
        weekdaySymbols = (1...7).map { KoyomiCalendar.weekdaySymbol(weekday: $0) }
        cells = month.days.map { day in
            let assignment = day.dayKey.flatMap { assignments[$0] }
            return ShiftShareCell(
                id: day.id,
                day: day.day,
                weekday: day.weekday,
                label: assignment?.definition.shortLabel,
                color: assignment?.definition.color,
                isRest: assignment?.definition.kind == .rest,
                holidayName: day.dayKey.flatMap { holidays[$0] }
            )
        }

        var seen = Set<String>()
        var legend: [(label: String, color: ShiftColor, isRest: Bool)] = []
        for key in month.dayKeys {
            guard let assignment = assignments[key] else { continue }
            let definition = assignment.definition
            guard seen.insert(definition.name).inserted else { continue }
            legend.append((definition.name, definition.color, definition.kind == .rest))
        }
        self.legend = legend
    }
}
