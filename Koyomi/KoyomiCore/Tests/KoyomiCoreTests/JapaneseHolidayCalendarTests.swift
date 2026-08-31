import XCTest
@testable import KoyomiCore

final class JapaneseHolidayCalendarTests: XCTestCase {
    func testFixedHolidays2026() {
        let holidays = JapaneseHolidayCalendar.holidays(year: 2026)
        XCTAssertEqual(holidays["2026-01-01"], "元日")
        XCTAssertEqual(holidays["2026-02-11"], "建国記念の日")
        XCTAssertEqual(holidays["2026-02-23"], "天皇誕生日")
        XCTAssertEqual(holidays["2026-04-29"], "昭和の日")
        XCTAssertEqual(holidays["2026-05-03"], "憲法記念日")
        XCTAssertEqual(holidays["2026-05-04"], "みどりの日")
        XCTAssertEqual(holidays["2026-05-05"], "こどもの日")
        XCTAssertEqual(holidays["2026-08-11"], "山の日")
        XCTAssertEqual(holidays["2026-11-03"], "文化の日")
        XCTAssertEqual(holidays["2026-11-23"], "勤労感謝の日")
    }

    func testHappyMondayHolidays() {
        // 成人の日 = 1 月第 2 月曜、海の日 = 7 月第 3 月曜、敬老の日 = 9 月第 3 月曜、スポーツの日 = 10 月第 2 月曜。
        let holidays2026 = JapaneseHolidayCalendar.holidays(year: 2026)
        XCTAssertEqual(holidays2026["2026-01-12"], "成人の日")
        XCTAssertEqual(holidays2026["2026-07-20"], "海の日")
        XCTAssertEqual(holidays2026["2026-09-21"], "敬老の日")
        XCTAssertEqual(holidays2026["2026-10-12"], "スポーツの日")

        let holidays2025 = JapaneseHolidayCalendar.holidays(year: 2025)
        XCTAssertEqual(holidays2025["2025-01-13"], "成人の日")
        XCTAssertEqual(holidays2025["2025-07-21"], "海の日")
        XCTAssertEqual(holidays2025["2025-10-13"], "スポーツの日")
    }

    func testEquinoxDays() {
        XCTAssertEqual(JapaneseHolidayCalendar.vernalEquinoxDay(year: 2026), 20)
        XCTAssertEqual(JapaneseHolidayCalendar.vernalEquinoxDay(year: 2027), 21)
        XCTAssertEqual(JapaneseHolidayCalendar.autumnalEquinoxDay(year: 2026), 23)
        XCTAssertEqual(JapaneseHolidayCalendar.autumnalEquinoxDay(year: 2024), 22)

        XCTAssertEqual(JapaneseHolidayCalendar.holidays(year: 2026)["2026-03-20"], "春分の日")
        XCTAssertEqual(JapaneseHolidayCalendar.holidays(year: 2026)["2026-09-23"], "秋分の日")
        XCTAssertEqual(JapaneseHolidayCalendar.holidays(year: 2024)["2024-09-22"], "秋分の日")
    }

    func testSubstituteHoliday() {
        // 2027-01-01 は金曜だが、2028-01-01 は土曜、2023-01-01 は日曜で 1/2 が振替休日。
        XCTAssertEqual(JapaneseHolidayCalendar.holidays(year: 2023)["2023-01-02"], "振替休日")
        // 2026-05-03（日）→ 5/6 が振替休日（5/4・5/5 は祝日）。
        let holidays2026 = JapaneseHolidayCalendar.holidays(year: 2026)
        XCTAssertEqual(holidays2026["2026-05-06"], "振替休日")
        // 2025-11-03 は月曜なので振替休日は発生しない。
        XCTAssertNil(JapaneseHolidayCalendar.holidays(year: 2025)["2025-11-04"])
    }

    func testNationalHolidaySandwichedBetweenHolidays() {
        // 2026 年は 9/21（敬老の日・月）と 9/23（秋分の日・水）の間の 9/22 が国民の休日。
        XCTAssertEqual(JapaneseHolidayCalendar.holidays(year: 2026)["2026-09-22"], "国民の休日")
        XCTAssertEqual(JapaneseHolidayCalendar.holidays(year: 2032)["2032-09-21"], "国民の休日")
    }

    func testTwoThousandTwentyOneSpecialDates() {
        let holidays = JapaneseHolidayCalendar.holidays(year: 2021)
        XCTAssertEqual(holidays["2021-07-22"], "海の日")
        XCTAssertEqual(holidays["2021-07-23"], "スポーツの日")
        XCTAssertEqual(holidays["2021-08-08"], "山の日")
        XCTAssertEqual(holidays["2021-08-09"], "振替休日")
        XCTAssertNil(holidays["2021-10-11"])
    }

    func testMonthFilterAndLookupHelpers() {
        let september = JapaneseHolidayCalendar.holidays(year: 2026, month: 9)
        XCTAssertEqual(september.count, 3)
        XCTAssertTrue(september.keys.allSatisfy { $0.hasPrefix("2026-09") })
        XCTAssertEqual(JapaneseHolidayCalendar.holidayName(dayKey: "2026-01-01"), "元日")
        XCTAssertTrue(JapaneseHolidayCalendar.isHoliday(dayKey: "2026-05-05"))
        XCTAssertFalse(JapaneseHolidayCalendar.isHoliday(dayKey: "2026-05-07"))
        XCTAssertNil(JapaneseHolidayCalendar.holidayName(dayKey: "not-a-day"))
    }

    func testCoversTenYearWindowWithoutOnlineData() {
        // 現在年の前後 5 年ぶんは必ず祝日が取得できる。
        for year in 2021...2031 {
            let holidays = JapaneseHolidayCalendar.holidays(year: year)
            XCTAssertGreaterThanOrEqual(holidays.count, 16, "\(year) 年の祝日が不足している")
            XCTAssertTrue(holidays.keys.allSatisfy { KoyomiCalendar.date(fromDayKey: $0) != nil })
        }
        XCTAssertTrue(JapaneseHolidayCalendar.holidays(year: 1800).isEmpty)
    }
}
