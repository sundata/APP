import XCTest
@testable import KoyomiCore

final class KoyomiCalendarTests: XCTestCase {
    private let tokyo = KoyomiCalendar.calendar(timeZoneIdentifier: "Asia/Tokyo")

    func testDayKeyUsesLocalDate() {
        // 2026-08-29 23:30 JST = 2026-08-29（UTC では 14:30 で前日ではない）
        let date = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 23, minute: 30))!
        XCTAssertEqual(KoyomiCalendar.dayKey(for: date, calendar: tokyo), "2026-08-29")
    }

    func testDayKeyDiffersAcrossTimeZonesAtMidnight() {
        // 2026-08-30 00:30 JST は、ハワイ時間ではまだ 8/29。
        let date = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 0, minute: 30))!
        let honolulu = KoyomiCalendar.calendar(timeZoneIdentifier: "Pacific/Honolulu")
        XCTAssertEqual(KoyomiCalendar.dayKey(for: date, calendar: tokyo), "2026-08-30")
        XCTAssertEqual(KoyomiCalendar.dayKey(for: date, calendar: honolulu), "2026-08-29")
    }

    func testDayNumberIncrementsByOnePerLocalDay() {
        let start = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 9))!
        let base = KoyomiCalendar.dayNumber(for: start, calendar: tokyo)
        for offset in 1...30 {
            let next = tokyo.date(byAdding: .day, value: offset, to: start)!
            XCTAssertEqual(KoyomiCalendar.dayNumber(for: next, calendar: tokyo), base + offset)
        }
    }

    func testDayNumberIsStableWithinTheSameDay() {
        let morning = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 0, minute: 1))!
        let night = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 23, minute: 59))!
        XCTAssertEqual(
            KoyomiCalendar.dayNumber(for: morning, calendar: tokyo),
            KoyomiCalendar.dayNumber(for: night, calendar: tokyo)
        )
    }

    func testDayNumberAcrossLeapDay() {
        let feb28 = tokyo.date(from: DateComponents(year: 2024, month: 2, day: 28, hour: 12))!
        let mar1 = tokyo.date(from: DateComponents(year: 2024, month: 3, day: 1, hour: 12))!
        XCTAssertEqual(
            KoyomiCalendar.dayNumber(for: mar1, calendar: tokyo) - KoyomiCalendar.dayNumber(for: feb28, calendar: tokyo),
            2
        )
    }

    func testSeasonMapping() {
        XCTAssertEqual(Season.from(month: 4), .spring)
        XCTAssertEqual(Season.from(month: 7), .summer)
        XCTAssertEqual(Season.from(month: 10), .autumn)
        XCTAssertEqual(Season.from(month: 1), .winter)
    }

    func testDisplayDateIsJapanese() {
        let date = tokyo.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 12))!
        XCTAssertEqual(KoyomiCalendar.displayDate(for: date, calendar: tokyo), "8月29日（土）")
    }
}
