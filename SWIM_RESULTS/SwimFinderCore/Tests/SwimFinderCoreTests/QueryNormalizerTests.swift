import XCTest
@testable import SwimFinderCore

final class QueryNormalizerTests: XCTestCase {
    func testTrimsAndCollapsesWhitespace() {
        XCTAssertEqual(QueryNormalizer.normalize("  山田   花子  "), "山田 花子")
        XCTAssertEqual(QueryNormalizer.normalize("山田\u{3000}花子"), "山田 花子")
        XCTAssertEqual(QueryNormalizer.normalize("\u{3000}山田\u{3000}\u{3000}花子\u{3000}"), "山田 花子")
        XCTAssertEqual(QueryNormalizer.normalize("山田\t\n花子"), "山田 花子")
        XCTAssertEqual(QueryNormalizer.normalize("   "), "")
    }

    func testDoesNotAlterCharacters() {
        XCTAssertEqual(QueryNormalizer.normalize("ヤマダ ﾊﾅｺ"), "ヤマダ ﾊﾅｺ")
        XCTAssertEqual(QueryNormalizer.normalize("Yamada"), "Yamada")
    }

    func testMinimumLength() {
        XCTAssertFalse(QueryNormalizer.isSearchable(""))
        XCTAssertFalse(QueryNormalizer.isSearchable("山"))
        XCTAssertFalse(QueryNormalizer.isSearchable(" 山 "))
        XCTAssertTrue(QueryNormalizer.isSearchable("山田"))
        XCTAssertTrue(QueryNormalizer.isSearchable("山 田"))
    }

    func testSplitName() {
        XCTAssertEqual(QueryNormalizer.splitName("山田 花子").family, "山田")
        XCTAssertEqual(QueryNormalizer.splitName("山田 花子").given, "花子")
        XCTAssertEqual(QueryNormalizer.splitName("山田").family, "山田")
        XCTAssertNil(QueryNormalizer.splitName("山田").given)
        XCTAssertEqual(QueryNormalizer.splitName("山田 花子 二郎").given, "花子 二郎")
    }

    func testMeetQueryNormalizedPreservesRaw() {
        let query = MeetQuery(rawName: " 日本選手権  水泳 ", fiscalYear: 2026)
        XCTAssertEqual(query.rawName, " 日本選手権  水泳 ")
        XCTAssertEqual(query.name, "日本選手権 水泳")
    }
}
