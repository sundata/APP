import XCTest
@testable import ShiftTechoCore

final class ShiftShareContentTests: XCTestCase {
    private let month = CalendarMonth(year: 2026, month: 3)

    private func assignments() -> [String: ShiftAssignment] {
        let templates = ShiftTemplate.defaults
        let night = templates[3]
        let rest = templates[4]
        return [
            "2026-03-01": ShiftAssignment(dayKey: "2026-03-01", templateID: night.id, definition: night.definition, note: "通院メモ"),
            "2026-03-02": ShiftAssignment(dayKey: "2026-03-02", templateID: rest.id, definition: rest.definition)
        ]
    }

    func testContentUsesLabelsAndLegendOnly() {
        let content = ShiftShareContent(
            month: month,
            assignments: assignments(),
            holidays: JapaneseHolidayCalendar.holidays(year: 2026, month: 3)
        )
        XCTAssertEqual(content.title, "2026年3月")
        XCTAssertEqual(content.weekdaySymbols, ["日", "月", "火", "水", "木", "金", "土"])
        XCTAssertEqual(content.brandName, "シフト手帳")
        XCTAssertEqual(content.cells.first?.label, "夜勤")
        XCTAssertEqual(content.cells.first?.color, .purple)
        XCTAssertEqual(content.cells[1].isRest, true)
        XCTAssertEqual(content.legend.map(\.label), ["夜勤", "休み"])
        XCTAssertEqual(content.cells.first(where: { $0.day == 20 })?.holidayName, "春分の日")
    }

    func testEmptyMonthIsDetected() {
        let empty = ShiftShareContent(month: month, assignments: [:])
        XCTAssertTrue(empty.isEmpty)
        XCTAssertTrue(empty.legend.isEmpty)
        XCTAssertFalse(ShiftShareContent(month: month, assignments: assignments()).isEmpty)
    }

    func testCellsCannotCarryNotesOrMoney() {
        // 共有画像に渡せるのはラベル・色・祝日名だけ。メモや金額は型として存在しない。
        let content = ShiftShareContent(month: month, assignments: assignments())
        let mirror = Mirror(reflecting: content.cells[0])
        let labels = mirror.children.compactMap(\.label)
        XCTAssertEqual(Set(labels), Set(["id", "day", "weekday", "label", "color", "isRest", "holidayName"]))
    }
}
