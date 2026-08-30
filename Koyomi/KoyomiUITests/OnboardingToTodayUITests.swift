import XCTest

/// onboarding から今日ページまでの最小の UI テスト。
/// `-uiTesting` で mock 天気・固定時計・権限ダイアログなしの構成になる。
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

        XCTAssertTrue(app.staticTexts["今日の空は、今日のあなたの味方。"].waitForExistence(timeout: 5))
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

        XCTAssertTrue(app.staticTexts["今日の運勢"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["空からのサイン"].exists)
        XCTAssertTrue(app.buttons["today.share"].exists)
        XCTAssertTrue(app.staticTexts["今日の小さなアクション"].exists)
    }

    /// App Store 提出用の実画面キャプチャ。生成画像ではなく、固定データの UI を撮影する。
    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["今日の運勢"].waitForExistence(timeout: 10))
        attachScreenshot(named: "03-today")

        app.tabBars.buttons["カレンダー"].tap()
        XCTAssertTrue(app.staticTexts["星のチャーム"].waitForExistence(timeout: 5))
        attachScreenshot(named: "04-calendar")

        app.tabBars.buttons["わたし"].tap()
        XCTAssertTrue(app.navigationBars["わたし"].waitForExistence(timeout: 5))
        attachScreenshot(named: "05-profile")

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
        attachScreenshot(named: "06-share-card")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
