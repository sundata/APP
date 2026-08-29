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
}
