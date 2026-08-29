import XCTest
@testable import KoyomiCore

final class ShareCardContentTests: XCTestCase {
    private let calendar = KoyomiCalendar.japan

    private func fortune() -> DailyFortune {
        let date = calendar.date(from: DateComponents(year: 2026, month: 8, day: 29, hour: 9))!
        let snapshot = WeatherSnapshot(
            category: .cloudy,
            temperature: 26,
            highTemperature: 30,
            lowTemperature: 22,
            precipitationChance: 0.2,
            humidity: 0.7,
            windSpeed: 1.8,
            cityName: "東京",
            capturedAt: date
        )
        return TemplateFortuneGenerator().fortune(
            for: FortuneInput(zodiac: .virgo, date: date, calendar: calendar, weather: snapshot)
        )
    }

    // 受入シナリオ 6: 個人情報がシェアカードに入らない。
    func testShareCardContainsNoPersonalInformation() {
        let card = ShareCardContent(fortune: fortune(), dateText: "2026.08.29")
        let rendered = [card.dateText, card.zodiacName, card.headline, card.shortMessage, card.luckyColor.name, card.brandName, card.disclaimer]
            .joined(separator: " ")
        for personal in ["さくら", "東京", "1998", "生年月日", "ニックネーム"] {
            XCTAssertFalse(rendered.contains(personal), "個人情報が含まれている: \(personal)")
        }
    }

    func testShortMessageIsASingleSentence() {
        let card = ShareCardContent(fortune: fortune(), dateText: "2026.08.29")
        XCTAssertTrue(card.shortMessage.hasSuffix("。"))
        XCTAssertEqual(card.shortMessage.filter { $0 == "。" }.count, 1)
        XCTAssertLessThanOrEqual(card.shortMessage.count, 70)
    }

    func testWeatherSnapshotFormatting() {
        let date = Date(timeIntervalSince1970: 1_770_000_000)
        let snapshot = WeatherSnapshot(
            category: .rain,
            temperature: 18.4,
            highTemperature: 21.6,
            lowTemperature: 15.2,
            precipitationChance: 0.65,
            humidity: 0.8,
            windSpeed: 3.1,
            cityName: "大阪",
            capturedAt: date
        )
        XCTAssertEqual(snapshot.temperatureText, "18°")
        XCTAssertEqual(snapshot.highLowText, "最高22° / 最低15°")
        XCTAssertEqual(snapshot.precipitationText, "降水確率 65%")
        XCTAssertFalse(snapshot.isStale(now: date.addingTimeInterval(30 * 60)))
        XCTAssertTrue(snapshot.isStale(now: date.addingTimeInterval(2 * 3600)))
    }

    func testSelectableCitiesCoverRequiredList() {
        let names = Set(City.selectable.map(\.japaneseName))
        for required in ["東京", "大阪", "名古屋", "札幌", "福岡", "仙台", "広島", "那覇"] {
            XCTAssertTrue(names.contains(required), required)
        }
        XCTAssertEqual(City.city(id: "tokyo")?.japaneseName, "東京")
        XCTAssertNil(City.city(id: "unknown"))
    }

    func testStableSeedIsDeterministicAcrossInstances() {
        XCTAssertEqual(StableSeed("2026-08-29|virgo|clear|v1").value, StableSeed("2026-08-29|virgo|clear|v1").value)
        XCTAssertNotEqual(StableSeed("2026-08-29|virgo|clear|v1").value, StableSeed("2026-08-30|virgo|clear|v1").value)
        // FNV-1a 64bit の既知値（実行ごとに変わらないことの担保）。
        XCTAssertEqual(StableSeed("").value, 0xcbf2_9ce4_8422_2325)
        XCTAssertEqual(StableSeed("a").value, 0xaf63_dc4c_8601_ec8c)
        XCTAssertNotEqual(StableSeed("seed").derived("love").value, StableSeed("seed").derived("work").value)
    }
}
