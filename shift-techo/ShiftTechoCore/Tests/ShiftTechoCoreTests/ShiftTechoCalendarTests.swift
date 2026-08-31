import XCTest
@testable import ShiftTechoCore

final class ShiftTechoCalendarTests: XCTestCase {
    private let tokyo = ShiftTechoCalendar.calendar(timeZoneIdentifier: "Asia/Tokyo")

    func testDayKeyUsesLocalDate() {
        // 2026-08-29 23:30 JST = 2026-08-29（UTC では 14:30 で前日ではない）
        let date = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 23, minute: 30))!
        XCTAssertEqual(ShiftTechoCalendar.dayKey(for: date, calendar: tokyo), "2026-08-29")
    }

    func testDayKeyDiffersAcrossTimeZonesAtMidnight() {
        // 2026-08-30 00:30 JST は、ハワイ時間ではまだ 8/29。
        let date = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 0, minute: 30))!
        let honolulu = ShiftTechoCalendar.calendar(timeZoneIdentifier: "Pacific/Honolulu")
        XCTAssertEqual(ShiftTechoCalendar.dayKey(for: date, calendar: tokyo), "2026-08-30")
        XCTAssertEqual(ShiftTechoCalendar.dayKey(for: date, calendar: honolulu), "2026-08-29")
    }

    func testDayNumberIncrementsByOnePerLocalDay() {
        let start = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 9))!
        let base = ShiftTechoCalendar.dayNumber(for: start, calendar: tokyo)
        for offset in 1...30 {
            let next = tokyo.date(byAdding: .day, value: offset, to: start)!
            XCTAssertEqual(ShiftTechoCalendar.dayNumber(for: next, calendar: tokyo), base + offset)
        }
    }

    func testDayNumberIsStableWithinTheSameDay() {
        let morning = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 0, minute: 1))!
        let night = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 23, minute: 59))!
        XCTAssertEqual(
            ShiftTechoCalendar.dayNumber(for: morning, calendar: tokyo),
            ShiftTechoCalendar.dayNumber(for: night, calendar: tokyo)
        )
    }

    func testDayNumberAcrossLeapDay() {
        let feb28 = tokyo.date(from: DateComponents(year: 2024, month: 2, day: 28, hour: 12))!
        let mar1 = tokyo.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 12))!
        XCTAssertEqual(
            ShiftTechoCalendar.dayNumber(for: mar1, calendar: tokyo) - ShiftTechoCalendar.dayNumber(for: feb28, calendar: tokyo),
            2
        )
    }

    func testDayKeyRoundTrip() {
        let date = ShiftTechoCalendar.date(fromDayKey: "2026-02-28")
        XCTAssertNotNil(date)
        XCTAssertEqual(ShiftTechoCalendar.dayKey(for: date!), "2026-02-28")
        XCTAssertEqual(ShiftTechoCalendar.components(fromDayKey: "2026-02-28")?.month, 2)
    }

    func testInvalidDayKeysAreRejected() {
        XCTAssertNil(ShiftTechoCalendar.date(fromDayKey: "2026-02-30"))
        XCTAssertNil(ShiftTechoCalendar.date(fromDayKey: "2026-13-01"))
        XCTAssertNil(ShiftTechoCalendar.date(fromDayKey: "2026-2-1"))
        XCTAssertNil(ShiftTechoCalendar.date(fromDayKey: ""))
    }

    func testLeapYearFebruary() {
        XCTAssertNotNil(ShiftTechoCalendar.date(fromDayKey: "2024-02-29"))
        XCTAssertNil(ShiftTechoCalendar.date(fromDayKey: "2026-02-29"))
        XCTAssertEqual(CalendarMonth(year: 2024, month: 2).dayKeys.count, 29)
        XCTAssertEqual(CalendarMonth(year: 2026, month: 2).dayKeys.count, 28)
    }

    func testDayKeysRangeIsInclusiveAndOrderAgnostic() {
        let start = tokyo.date(from: DateComponents(year: 2026, month: 4, day: 28, hour: 22))!
        let end = tokyo.date(from: DateComponents(year: 2026, month: 5, day: 2, hour: 3))!
        XCTAssertEqual(
            ShiftTechoCalendar.dayKeys(from: start, to: end, calendar: tokyo),
            ["2026-04-28", "2026-04-29", "2026-04-30", "2026-05-01", "2026-05-02"]
        )
        XCTAssertEqual(
            ShiftTechoCalendar.dayKeys(from: end, to: start, calendar: tokyo).count,
            5
        )
    }

    func testTimeTextWrapsPastMidnight() {
        XCTAssertEqual(ShiftTechoCalendar.timeText(minuteOfDay: 0), "00:00")
        XCTAssertEqual(ShiftTechoCalendar.timeText(minuteOfDay: 22 * 60), "22:00")
        XCTAssertEqual(ShiftTechoCalendar.timeText(minuteOfDay: 25 * 60), "01:00")
    }

    func testMonthGridStartsOnSundayAndFillsFullWeeks() {
        // 2026-03-01 は日曜なので先頭に空白マスはない。
        let march = CalendarMonth(year: 2026, month: 3)
        XCTAssertEqual(march.days.first?.dayKey, "2026-03-01")
        XCTAssertEqual(march.days.count % 7, 0)
        XCTAssertEqual(march.title, "2026年3月")

        // 2026-04-01 は水曜なので日〜火の 3 マスが空白になる。
        let april = CalendarMonth(year: 2026, month: 4)
        XCTAssertEqual(april.days.prefix(3).filter(\.isPlaceholder).count, 3)
        XCTAssertEqual(april.days[3].dayKey, "2026-04-01")
        XCTAssertEqual(april.dayKeys.count, 30)
        XCTAssertEqual(april.adding(months: 1).month, 5)
        XCTAssertEqual(april.adding(months: -4).year, 2025)
    }

    func testTokyoDayKeysAreStableWithoutDaylightSaving() {
        // 日本には夏時間がないため、3 月・11 月の境界でも 0 時ちょうどで日付が変わる。
        for month in [3, 11] {
            let midnight = tokyo.date(from: DateComponents(year: 2026, month: month, day: 8, hour: 0, minute: 0))!
            let justBefore = midnight.addingTimeInterval(-60)
            XCTAssertEqual(ShiftTechoCalendar.dayKey(for: midnight, calendar: tokyo), "2026-\(String(format: "%02d", month))-08")
            XCTAssertEqual(ShiftTechoCalendar.dayKey(for: justBefore, calendar: tokyo), "2026-\(String(format: "%02d", month))-07")
            XCTAssertEqual(tokyo.timeZone.secondsFromGMT(for: midnight), 9 * 3600)
        }
    }

    func testDisplayDateIsJapanese() {
        let date = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 12))!
        XCTAssertEqual(ShiftTechoCalendar.displayDate(for: date, calendar: tokyo), "8月29日（土）")
    }
}
