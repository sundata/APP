import XCTest
@testable import KoyomiCore

final class ContentLibraryTests: XCTestCase {
    func testEveryZodiacHasAtLeastTwentyThemes() {
        for zodiac in Zodiac.allCases {
            let indices = ContentLibrary.themeIndices(for: zodiac)
            XCTAssertGreaterThanOrEqual(indices.count, 20, "\(zodiac) のテーマ数")
            XCTAssertEqual(Set(indices).count, indices.count, "\(zodiac) のテーマが重複している")
        }
    }

    func testEveryWeatherCategoryHasAtLeastTenHints() {
        for category in WeatherCategory.allCases {
            let hints = ContentLibrary.weatherHints[category] ?? []
            XCTAssertGreaterThanOrEqual(hints.count, 10, "\(category) のヒント数")
            XCTAssertEqual(Set(hints).count, hints.count, "\(category) のヒントが重複している")
        }
    }

    func testEverySeasonHasFallbackHints() {
        for season in Season.allCases {
            XCTAssertGreaterThanOrEqual((ContentLibrary.seasonHints[season] ?? []).count, 6, "\(season)")
        }
    }

    func testEveryZodiacHasFlavors() {
        for zodiac in Zodiac.allCases {
            XCTAssertGreaterThanOrEqual((ContentLibrary.zodiacFlavors[zodiac] ?? []).count, 4, "\(zodiac)")
        }
    }

    func testCategoryTextPoolsAreLargeEnough() {
        XCTAssertGreaterThanOrEqual(ContentLibrary.loveTexts.count, 12)
        XCTAssertGreaterThanOrEqual(ContentLibrary.workStudyTexts.count, 12)
        XCTAssertGreaterThanOrEqual(ContentLibrary.beautyHealthTexts.count, 12)
        XCTAssertGreaterThanOrEqual(ContentLibrary.socialTexts.count, 12)
        XCTAssertGreaterThanOrEqual(ContentLibrary.actions.count, 30)
        XCTAssertGreaterThanOrEqual(ContentLibrary.luckyItems.count, 20)
        XCTAssertGreaterThanOrEqual(ContentLibrary.luckyColors.count, 12)
    }

    func testLuckyColorsUseValidHexAndUniqueNames() {
        for color in ContentLibrary.luckyColors {
            XCTAssertEqual(color.hex.count, 7, color.hex)
            XCTAssertTrue(color.hex.hasPrefix("#"), color.hex)
            let hexDigits = color.hex.dropFirst()
            XCTAssertTrue(hexDigits.allSatisfy { $0.isHexDigit }, color.hex)
        }
        XCTAssertEqual(Set(ContentLibrary.luckyColors.map(\.name)).count, ContentLibrary.luckyColors.count)
    }

    // 要件 5.4 / 受入シナリオ 8: 断定・不安をあおる表現や扱わない領域を含まない。
    func testNoForbiddenExpressions() {
        for text in ContentSafety.allUserFacingContent {
            let violations = ContentSafety.violations(in: text)
            XCTAssertTrue(violations.isEmpty, "『\(text)』に禁止語 \(violations)")
        }
    }

    // 要件 2-10: ユーザーに見える文章に中国語（簡体字）や開発用の文字列が混ざらない。
    func testContentIsJapaneseOnly() {
        let latinLetters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ")
        let allowedLatin = ["BGM"]
        for text in ContentSafety.allUserFacingContent {
            var stripped = text
            for allowed in allowedLatin { stripped = stripped.replacingOccurrences(of: allowed, with: "") }
            XCTAssertNil(
                stripped.rangeOfCharacter(from: latinLetters),
                "日本語以外の文字が含まれている: 『\(text)』"
            )
        }
    }

    func testTextsEndWithJapanesePunctuation() {
        let sentencePools = [
            ContentLibrary.loveTexts,
            ContentLibrary.workStudyTexts,
            ContentLibrary.beautyHealthTexts,
            ContentLibrary.socialTexts,
            ContentLibrary.notificationMessages
        ]
        for pool in sentencePools {
            for text in pool {
                XCTAssertTrue(["。", "？", "！"].contains(String(text.suffix(1))), "文末が不自然: 『\(text)』")
            }
        }
    }

    func testActionsAreShortAndConcrete() {
        for action in ContentLibrary.actions {
            XCTAssertLessThanOrEqual(action.count, 30, "アクションが長すぎる: \(action)")
            XCTAssertFalse(action.hasSuffix("。"), "アクションは体言止めで揃える: \(action)")
        }
        XCTAssertEqual(Set(ContentLibrary.actions).count, ContentLibrary.actions.count)
    }
}
