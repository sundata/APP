import XCTest
@testable import KoyomiCore

final class ZodiacTests: XCTestCase {
    func testEveryDayOfTheYearMapsToAZodiac() {
        let calendar = KoyomiCalendar.japan
        var components = DateComponents()
        components.year = 2025
        for month in 1...12 {
            for day in 1...31 {
                components.month = month
                components.day = day
                guard let date = calendar.date(from: components),
                      calendar.component(.month, from: date) == month else { continue }
                let zodiac = Zodiac.from(date: date, calendar: calendar)
                XCTAssertTrue(Zodiac.allCases.contains(zodiac), "\(month)/\(day) の星座判定に失敗")
            }
        }
    }

    func testZodiacBoundaryDays() {
        let expectations: [(Int, Int, Zodiac)] = [
            (3, 20, .pisces), (3, 21, .aries),
            (4, 19, .aries), (4, 20, .taurus),
            (8, 22, .leo), (8, 23, .virgo),
            (9, 22, .virgo), (9, 23, .libra),
            (12, 21, .sagittarius), (12, 22, .capricorn),
            (1, 19, .capricorn), (1, 20, .aquarius),
            (2, 18, .aquarius), (2, 19, .pisces)
        ]
        for (month, day, expected) in expectations {
            XCTAssertEqual(Zodiac.from(month: month, day: day), expected, "\(month)/\(day)")
        }
    }

    func testLeapDayIsPisces() {
        let calendar = KoyomiCalendar.japan
        let leapDay = calendar.date(from: DateComponents(year: 2024, month: 2, day: 29))!
        XCTAssertEqual(calendar.component(.day, from: leapDay), 29)
        XCTAssertEqual(Zodiac.from(date: leapDay, calendar: calendar), .pisces)
    }

    func testOrdinalsAreUnique() {
        XCTAssertEqual(Set(Zodiac.allCases.map(\.ordinal)).count, Zodiac.allCases.count)
    }
}
