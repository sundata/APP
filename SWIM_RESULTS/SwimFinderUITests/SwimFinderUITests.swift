import XCTest

final class SwimFinderUITests: XCTestCase {
    private func launch(seeded: Bool = false, contentSize: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if seeded { app.launchArguments.append("-seedHistory") }
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    func testHomeShowsUnofficialNoticeAndEntries() {
        let app = launch()
        XCTAssertTrue(app.buttons["home.playerSearch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.meetSearch"].exists)
        XCTAssertTrue(app.staticTexts["home.emptyRecents"].exists)
        XCTAssertTrue(app.otherElements["unofficialNotice"].exists || app.staticTexts["unofficialNotice"].exists)
    }

    func testPlayerSearchOpensOfficialSiteAndRecordsHistory() {
        let app = launch()
        app.buttons["home.playerSearch"].tap()

        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let openButton = app.buttons["player.openOfficialSite"]
        XCTAssertFalse(openButton.isEnabled, "空欄では検索できない")

        field.tap()
        field.typeText("  架空\u{3000}太郎 ")
        XCTAssertTrue(openButton.isEnabled)
        openButton.tap()

        let urlLabel = app.staticTexts["officialURLLabel"]
        XCTAssertTrue(urlLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(urlLabel.label, "https://result.swim.or.jp/player-search")
        XCTAssertTrue(app.staticTexts["guidanceLabel"].label.contains("架空 太郎"))
        app.buttons["closeOfficialSite"].tap()

        app.navigationBars.buttons.element(boundBy: 0).tap()
        let recent = app.buttons["recent.player"]
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        XCTAssertTrue(recent.label.contains("架空 太郎"))
    }

    func testMeetSearchWithYear() {
        let app = launch()
        app.buttons["home.meetSearch"].tap()
        let field = app.textFields["meet.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("サンプル市民水泳大会")
        app.buttons["meet.openOfficialSite"].tap()

        let urlLabel = app.staticTexts["officialURLLabel"]
        XCTAssertTrue(urlLabel.waitForExistence(timeout: 5))
        XCTAssertEqual(urlLabel.label, "https://result.swim.or.jp/tournament/list")
        app.buttons["closeOfficialSite"].tap()
    }

    func testTooShortQueryShowsErrorNotZeroResults() {
        let app = launch()
        app.buttons["home.playerSearch"].tap()
        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("山")
        XCTAssertFalse(app.buttons["player.openOfficialSite"].isEnabled)
        XCTAssertFalse(app.staticTexts["officialURLLabel"].exists)
    }

    func testClearHistoryFromSettings() {
        let app = launch(seeded: true)
        XCTAssertTrue(app.buttons["recent.player"].waitForExistence(timeout: 5))

        app.tabBars.buttons["設定"].tap()
        let clear = app.buttons["settings.clearHistory"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        app.buttons["削除"].firstMatch.tap()

        app.tabBars.buttons["ホーム"].tap()
        XCTAssertTrue(app.staticTexts["home.emptyRecents"].waitForExistence(timeout: 5))
    }

    func testFavoritesRejectNonOfficialURL() {
        let app = launch(seeded: true)
        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.buttons["favorite.row"].firstMatch.waitForExistence(timeout: 5))

        app.buttons["favorites.add"].tap()
        let urlField = app.textFields["addFavorite.url"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5))
        urlField.tap()
        urlField.typeText("https://example.com/")
        app.buttons["addFavorite.save"].tap()
        XCTAssertTrue(app.otherElements["addFavorite.error"].waitForExistence(timeout: 3) || app.staticTexts["addFavorite.error"].exists)
    }

    func testAccessibilityExtraLargeTextStillNavigates() {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        XCTAssertTrue(app.buttons["home.playerSearch"].waitForExistence(timeout: 5))
        app.buttons["home.playerSearch"].tap()
        XCTAssertTrue(app.textFields["player.queryField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player.openOfficialSite"].exists)
    }
}
