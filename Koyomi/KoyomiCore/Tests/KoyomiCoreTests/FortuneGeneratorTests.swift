import XCTest
@testable import KoyomiCore

final class FortuneGeneratorTests: XCTestCase {
    private let generator = TemplateFortuneGenerator()
    private let calendar = KoyomiCalendar.japan

    private func snapshot(_ category: WeatherCategory, capturedAt: Date = Date(timeIntervalSince1970: 1_770_000_000)) -> WeatherSnapshot {
        WeatherSnapshot(
            category: category,
            temperature: 24,
            highTemperature: 28,
            lowTemperature: 19,
            precipitationChance: 0.3,
            humidity: 0.6,
            windSpeed: 2.4,
            cityName: "東京",
            capturedAt: capturedAt
        )
    }

    private func input(day: Int, month: Int = 8, year: Int = 2026, zodiac: Zodiac = .virgo, weather: WeatherCategory? = .clear) -> FortuneInput {
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 9))!
        return FortuneInput(
            zodiac: zodiac,
            date: date,
            calendar: calendar,
            weather: weather.map { snapshot($0) }
        )
    }

    // 受入シナリオ 4: 同じ日付・星座・天気なら結果は完全に一致する。
    func testSameInputProducesIdenticalFortune() {
        let first = generator.fortune(for: input(day: 29))
        let second = generator.fortune(for: input(day: 29))
        XCTAssertEqual(first, second)
    }

    func testResultIsStableEvenIfWeatherIsCapturedAtADifferentTime() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 9))!
        let morning = FortuneInput(zodiac: .virgo, date: date, calendar: calendar, weather: snapshot(.clear, capturedAt: date))
        let evening = FortuneInput(
            zodiac: .virgo,
            date: date,
            calendar: calendar,
            weather: snapshot(.clear, capturedAt: date.addingTimeInterval(6 * 3600))
        )
        XCTAssertEqual(generator.fortune(for: morning).headline, generator.fortune(for: evening).headline)
        XCTAssertEqual(generator.fortune(for: morning), generator.fortune(for: evening))
    }

    func testDifferentZodiacsGetDifferentThemesOnTheSameDay() {
        let headlines = Zodiac.allCases.map { generator.fortune(for: input(day: 29, zodiac: $0)).headline }
        XCTAssertGreaterThanOrEqual(Set(headlines).count, 8, "同じ日でも星座ごとに主題が十分に分かれること")
    }

    // 要件 5.2-7: 連続 7 日で同じ総評・同じアクションを出さない。
    func testNoRepeatWithinSevenDaysForEveryZodiacAndWeather() {
        for zodiac in Zodiac.allCases {
            for weather in WeatherCategory.allCases {
                for startDay in 1...25 {
                    let window = (0..<7).map { offset in
                        generator.fortune(for: input(day: startDay + offset, zodiac: zodiac, weather: weather))
                    }
                    XCTAssertEqual(Set(window.map(\.headline)).count, 7, "\(zodiac) / \(weather) / 開始 \(startDay) 日")
                    XCTAssertEqual(Set(window.map(\.overall)).count, 7, "\(zodiac) / \(weather) / 開始 \(startDay) 日")
                    XCTAssertEqual(Set(window.map(\.action)).count, 7, "\(zodiac) / \(weather) / 開始 \(startDay) 日")
                }
            }
        }
    }

    func testNoRepeatAcrossMonthBoundary() {
        let days = (0..<7).map { offset -> DailyFortune in
            let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 9))!
            let shifted = calendar.date(byAdding: .day, value: offset, to: date)!
            return generator.fortune(
                for: FortuneInput(zodiac: .virgo, date: shifted, calendar: calendar, weather: snapshot(.rain))
            )
        }
        XCTAssertEqual(Set(days.map(\.headline)).count, 7)
        XCTAssertEqual(Set(days.map(\.action)).count, 7)
    }

    func testScoresAreWithinRangeAndNeverPunishing() {
        for zodiac in Zodiac.allCases {
            for weather in WeatherCategory.allCases {
                for day in 1...28 {
                    let fortune = generator.fortune(for: input(day: day, zodiac: zodiac, weather: weather))
                    for score in [fortune.overallScore, fortune.love.score, fortune.workStudy.score, fortune.beautyHealth.score, fortune.social.score] {
                        XCTAssertTrue((2...5).contains(score), "スコアが範囲外: \(score)")
                    }
                }
            }
        }
    }

    // 受入シナリオ 3: 天気が無くても完全な結果を返し、天気を語らない。
    func testFallbackWithoutWeatherDoesNotMentionWeather() {
        let fortune = generator.fortune(for: input(day: 29, weather: nil))
        XCTAssertFalse(fortune.usedWeather)
        XCTAssertFalse(fortune.headline.isEmpty)
        XCTAssertFalse(fortune.overall.isEmpty)
        XCTAssertFalse(fortune.skySign.isEmpty)
        XCTAssertFalse(fortune.action.isEmpty)
        for word in ["晴れ", "雨", "雪", "雷", "気温", "猛暑", "霧", "強風"] {
            XCTAssertFalse(fortune.skySign.contains(word), "天気を推測して語っている: \(fortune.skySign)")
        }
    }

    func testWeatherCategoryChangesSkySign() {
        let clear = generator.fortune(for: input(day: 29, weather: .clear))
        let rain = generator.fortune(for: input(day: 29, weather: .rain))
        XCTAssertNotEqual(clear.skySign, rain.skySign)
    }

    func testMoonPhaseIsOnlyMentionedWhenProvided() {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 9))!
        let without = generator.fortune(
            for: FortuneInput(zodiac: .virgo, date: date, calendar: calendar, weather: snapshot(.clear))
        )
        let with = generator.fortune(
            for: FortuneInput(zodiac: .virgo, date: date, calendar: calendar, weather: snapshot(.clear), moonPhase: .fullMoon)
        )
        XCTAssertFalse(without.skySign.contains("満月"))
        XCTAssertTrue(with.skySign.contains("満月"))
    }

    func testLuckyTimeIsWithinWakingHours() {
        for day in 1...28 {
            let fortune = generator.fortune(for: input(day: day))
            let parts = fortune.luckyTime.split(separator: ":").compactMap { Int($0) }
            XCTAssertEqual(parts.count, 2)
            XCTAssertTrue((7...21).contains(parts[0]), "ラッキータイムが範囲外: \(fortune.luckyTime)")
            XCTAssertTrue((0...59).contains(parts[1]))
        }
    }

    func testOverallLengthIsReadable() {
        for zodiac in Zodiac.allCases {
            for day in 1...28 {
                let fortune = generator.fortune(for: input(day: day, zodiac: zodiac))
                XCTAssertTrue((80...120).contains(fortune.overall.count), "総評の文字数: \(fortune.overall.count)")
            }
        }
    }

    func testDisclaimerIsAlwaysPresent() {
        XCTAssertEqual(generator.fortune(for: input(day: 29)).disclaimer, DailyFortune.standardDisclaimer)
    }

    func testAccessibilityScoreText() {
        XCTAssertEqual(DailyFortune.accessibilityScoreText(4), "5段階中4")
    }

    // 要件 5.3: JSON の構造が仕様どおりであること（履歴の保存形式でもある）。
    func testJSONShapeMatchesSpecification() throws {
        let fortune = generator.fortune(for: input(day: 29))
        let data = try JSONEncoder().encode(fortune)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let expectedKeys: Set<String> = [
            "date", "zodiac", "overallScore", "headline", "overall", "skySign",
            "love", "workStudy", "beautyHealth", "social",
            "luckyColor", "luckyItem", "luckyTime", "action", "disclaimer",
            "contentVersion", "usedWeather"
        ]
        XCTAssertEqual(Set(object.keys), expectedKeys)
        XCTAssertEqual(object["date"] as? String, "2026-08-29")
        XCTAssertEqual(object["zodiac"] as? String, "virgo")
        let love = try XCTUnwrap(object["love"] as? [String: Any])
        XCTAssertEqual(Set(love.keys), ["score", "text"])
        let color = try XCTUnwrap(object["luckyColor"] as? [String: Any])
        XCTAssertEqual(Set(color.keys), ["name", "hex"])

        let restored = try JSONDecoder().decode(DailyFortune.self, from: data)
        XCTAssertEqual(restored, fortune)
    }

    func testContentVersionChangesResult() {
        let other = TemplateFortuneGenerator(contentVersion: ContentLibrary.contentVersion + 1)
        let a = generator.fortune(for: input(day: 29))
        let b = other.fortune(for: input(day: 29))
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(a.headline, b.headline, "テーマは日番号で決まるためバージョンに依存しない")
    }
}
