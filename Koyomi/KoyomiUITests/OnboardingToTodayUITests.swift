import XCTest

/// onboarding から今日ページまでの最小の UI テスト。
/// `-uiTesting` で mock 天気・固定時計・権限ダイアログなしの構成になる。
@MainActor
final class OnboardingToTodayUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
        return app
    }

    func testOnboardingReachesTodayWithFortune() {
        let app = launchApp()

        XCTAssertTrue(app.staticTexts["毎日ひとつ、自分にやさしい記録を。"].waitForExistence(timeout: 5))
        app.buttons["onboarding.next"].tap()

        let nickname = app.textFields["onboarding.nickname"]
        XCTAssertTrue(nickname.waitForExistence(timeout: 5))
        nickname.tap()
        nickname.typeText("さくら")
        app.buttons["onboarding.next"].tap()

        // 位置情報の権限ダイアログを出さずに都市を選ぶ。
        let chooseCity = app.buttons["onboarding.chooseCity"]
        XCTAssertTrue(chooseCity.waitForExistence(timeout: 5))
        chooseCity.tap()
        app.buttons["city.tokyo"].tap()

        // ユーザーが自分でオンにするまで通知は要求しない。
        let skipReminder = app.buttons["onboarding.skipReminder"]
        XCTAssertTrue(skipReminder.waitForExistence(timeout: 5))
        skipReminder.tap()

        XCTAssertTrue(app.staticTexts["今の気分は？"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["今日の小さなセルフケア"].exists)
        XCTAssertTrue(app.buttons["today.share"].exists)
        XCTAssertTrue(app.staticTexts["今日の小さなアクション"].exists)
    }

    func testChangingCityRefreshesTodayWhenReturningFromProfile() {
        let app = launchApp()
        completeOnboarding(in: app)

        XCTAssertTrue(app.staticTexts["東京 18°"].waitForExistence(timeout: 10))
        app.tabBars.buttons["わたし"].tap()
        app.buttons["profile.chooseCity"].tap()
        app.buttons["city.osaka"].tap()
        app.tabBars.buttons["今日"].tap()

        XCTAssertTrue(app.staticTexts["大阪 18°"].waitForExistence(timeout: 10))
    }

    func testCurrentLocationRefreshesTodayWhenEnabled() {
        let app = launchApp()
        completeOnboarding(in: app)

        app.tabBars.buttons["わたし"].tap()
        let currentLocation = app.switches["profile.useCurrentLocation"]
        XCTAssertEqual(currentLocation.value as? String, "0")
        currentLocation.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(currentLocation.value as? String, "1")
        app.tabBars.buttons["今日"].tap()

        XCTAssertTrue(app.staticTexts["大阪 18°"].waitForExistence(timeout: 10))
    }

    func testDailyRecordsPersistAcrossAllTabs() {
        let app = launchApp()
        completeOnboarding(in: app)

        app.buttons["気分：元気"].tap()
        XCTAssertTrue(app.staticTexts["その軽やかさを、好きなことに少し分けてみて。"].exists)

        let firstTask = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "未完了")).firstMatch
        XCTAssertTrue(firstTask.waitForExistence(timeout: 5))
        firstTask.tap()

        let reflection = app.textFields["160文字以内で、短く残してみて"]
        for _ in 0..<6 where !reflection.isHittable { app.swipeUp() }
        XCTAssertTrue(reflection.waitForExistence(timeout: 5))
        reflection.tap()
        reflection.typeText("今日はよくできた")
        app.buttons["残す"].tap()
        XCTAssertTrue(app.staticTexts["保存しました"].waitForExistence(timeout: 5))

        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["つづけた日のしるし"].waitForExistence(timeout: 5))
        app.tabBars.buttons["リズム"].tap()
        XCTAssertTrue(app.staticTexts["この30日の記録"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1"].firstMatch.exists)
        app.tabBars.buttons["今日"].tap()
        XCTAssertTrue(app.buttons["気分：元気"].isSelected)
    }

    /// App Store 提出用の実画面キャプチャ。生成画像ではなく、固定データの UI を撮影する。
    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["今の気分は？"].waitForExistence(timeout: 10))
        attachScreenshot(named: "03-today")

        app.tabBars.buttons["記録"].tap()
        XCTAssertTrue(app.staticTexts["つづけた日のしるし"].waitForExistence(timeout: 5))
        attachScreenshot(named: "04-calendar")

        app.tabBars.buttons["リズム"].tap()
        XCTAssertTrue(app.staticTexts["この30日の記録"].waitForExistence(timeout: 5))
        attachScreenshot(named: "05-rhythm")

        app.tabBars.buttons["わたし"].tap()
        XCTAssertTrue(app.navigationBars["わたし"].waitForExistence(timeout: 5))
        attachScreenshot(named: "06-profile")

        app.tabBars.buttons["今日"].tap()
        let shareButton = app.buttons["today.share"]
        for _ in 0..<8 where !shareButton.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(shareButton.waitForExistence(timeout: 5))
        shareButton.tap()
        XCTAssertTrue(app.navigationBars["シェアカード"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["share.preview"].waitForExistence(timeout: 5))
        sleep(2) // シート遷移と ImageRenderer の更新を待ってから撮影する。
        attachScreenshot(named: "07-share-card")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func completeOnboarding(in app: XCUIApplication) {
        XCTAssertTrue(app.staticTexts["毎日ひとつ、自分にやさしい記録を。"].waitForExistence(timeout: 5))
        app.buttons["onboarding.next"].tap()
        app.buttons["onboarding.next"].tap()
        app.buttons["onboarding.chooseCity"].tap()
        app.buttons["city.tokyo"].tap()
        app.buttons["onboarding.skipReminder"].tap()
    }
}
