import XCTest

/// シフトカレンダーの主要フローの UI テスト。
/// `-uiTesting` で広告なし・ネットワークなし・固定日付（2026-03-01 JST）・インメモリ DB になる。
final class ShiftCalendarUITests: XCTestCase {
    /// 固定時計の月。日付セルの識別子に使う。
    private let fixedMonthPrefix = "day-2026-03-"

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

    /// 引導を終えてカレンダーに入る。既定テンプレートはそのまま使う。
    private func completeOnboarding(_ app: XCUIApplication, wage: String? = nil) {
        XCTAssertTrue(app.staticTexts["シフトを、もっとかんたんに。"].waitForExistence(timeout: 10))
        app.buttons["onboardingPrimaryButton"].tap()
        XCTAssertTrue(app.staticTexts["シフトを用意しましょう"].waitForExistence(timeout: 5))
        app.buttons["onboardingPrimaryButton"].tap()

        if let wage {
            let field = app.textFields["onboardingWageField"]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            field.typeText(wage)
            app.buttons["onboardingPrimaryButton"].tap()
        } else {
            XCTAssertTrue(app.buttons["onboardingSkip"].waitForExistence(timeout: 5))
            app.buttons["onboardingSkip"].tap()
        }

        XCTAssertTrue(app.buttons["todayButton"].waitForExistence(timeout: 10))
    }

    private func dayCell(_ app: XCUIApplication, day: Int) -> XCUIElement {
        app.descendants(matching: .any)[fixedMonthPrefix + String(format: "%02d", day)]
    }

    private func assignShift(_ app: XCUIApplication, day: Int, template: String) {
        dayCell(app, day: day).tap()
        XCTAssertTrue(app.staticTexts["editorDateText"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["templateOption-\(template)"].tap()
        app.buttons["saveShiftButton"].tap()
    }

    // MARK: - 引導とカレンダー

    func testOnboardingReachesCalendar() {
        let app = launchApp()
        completeOnboarding(app)

        XCTAssertTrue(app.staticTexts["monthTitle"].exists)
        XCTAssertTrue(app.tabBars.buttons["カレンダー"].exists)
        XCTAssertTrue(app.tabBars.buttons["集計"].exists)
        XCTAssertTrue(app.tabBars.buttons["設定"].exists)
        // 広告は UI テストでは表示しない。
        XCTAssertFalse(app.otherElements["GADBannerView"].exists)
    }

    func testAssignEditAndDeleteSingleDay() {
        let app = launchApp()
        completeOnboarding(app)

        assignShift(app, day: 3, template: "日勤")
        XCTAssertTrue(dayCell(app, day: 3).label.contains("日勤"))

        // 同じ日を夜勤に更新しても重複しない。
        assignShift(app, day: 3, template: "夜勤")
        XCTAssertTrue(dayCell(app, day: 3).label.contains("夜勤"))

        dayCell(app, day: 3).tap()
        XCTAssertTrue(app.buttons["deleteShiftButton"].waitForExistence(timeout: 5))
        app.buttons["deleteShiftButton"].tap()

        XCTAssertTrue(dayCell(app, day: 3).label.contains("未設定"))
        // 削除直後は Undo できる。
        XCTAssertTrue(app.buttons["undoButton"].waitForExistence(timeout: 3))
    }

    func testBulkEntryAssignsRange() {
        let app = launchApp()
        completeOnboarding(app)

        app.buttons["bulkEntryButton"].tap()
        XCTAssertTrue(app.staticTexts["bulkDayCount"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["bulkTemplateOption-早番"].tap()
        app.buttons["bulkApplyButton"].tap()

        XCTAssertTrue(app.buttons["undoButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(dayCell(app, day: 1).label.contains("早番"))
    }

    // MARK: - 集計

    func testSummaryShowsHoursAndWage() {
        let app = launchApp()
        completeOnboarding(app, wage: "1200")

        assignShift(app, day: 2, template: "日勤")
        app.tabBars.buttons["集計"].tap()

        XCTAssertTrue(app.staticTexts["summaryMonthTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["summaryBillableHours"].label.contains("8時間"))
        XCTAssertTrue(app.descendants(matching: .any)["summaryEstimatedTotal"].exists)
        XCTAssertTrue(
            app.staticTexts["表示金額は概算です。実際の給与・税金・社会保険料とは異なる場合があります。"].exists
        )
    }

    func testSummaryShowsHintWhenWageMissing() {
        let app = launchApp()
        completeOnboarding(app)

        app.tabBars.buttons["集計"].tap()
        XCTAssertTrue(app.staticTexts["時給を設定すると表示されます"].waitForExistence(timeout: 5))
    }

    // MARK: - 共有

    func testSharePreviewHasNoWageOrNote() {
        let app = launchApp()
        completeOnboarding(app, wage: "1500")

        dayCell(app, day: 4).tap()
        XCTAssertTrue(app.staticTexts["editorDateText"].waitForExistence(timeout: 5))
        app.descendants(matching: .any)["templateOption-夜勤"].tap()
        let note = app.textFields["noteField"]
        note.tap()
        note.typeText("himitsu")
        app.buttons["saveShiftButton"].tap()

        app.buttons["shareButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["sharePreview"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["himitsu"].exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '1500'")).element.exists)
    }

    // MARK: - 通知

    func testNotificationPermissionOnlyAfterUserAction() {
        let app = launchApp()
        completeOnboarding(app)

        // 起動直後には権限ダイアログを出さない。
        XCTAssertFalse(app.alerts.element.exists)

        app.tabBars.buttons["設定"].tap()
        app.buttons["settingsRemindersLink"].tap()
        let toggle = app.switches["monthlyReminderToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        // StubNotificationScheduler は拒否を返すので、スイッチは戻り案内が出る。
        XCTAssertTrue(app.staticTexts["openSystemSettingsLink"].waitForExistence(timeout: 5)
            || app.buttons["openSystemSettingsLink"].waitForExistence(timeout: 5))
    }

    // MARK: - データ削除

    func testDeleteAllDataReturnsToOnboarding() {
        let app = launchApp()
        completeOnboarding(app)
        assignShift(app, day: 5, template: "休み")

        app.tabBars.buttons["設定"].tap()
        app.buttons["settingsDataLink"].tap()
        app.buttons["deleteAllDataButton"].tap()
        app.alerts.buttons["次へ"].tap()
        app.alerts.buttons["削除する"].tap()

        XCTAssertTrue(app.staticTexts["シフトを、もっとかんたんに。"].waitForExistence(timeout: 10))
    }

    // MARK: - スクリーンショット

    /// App Store 提出用のキャプチャ。固定データの実画面を撮影する。
    func testCaptureAppStoreScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshotTesting"]
        app.launch()

        XCTAssertTrue(app.staticTexts["monthTitle"].waitForExistence(timeout: 10))
        attachScreenshot(named: "01-calendar")

        app.tabBars.buttons["集計"].tap()
        XCTAssertTrue(app.staticTexts["summaryMonthTitle"].waitForExistence(timeout: 5))
        attachScreenshot(named: "02-summary")

        app.tabBars.buttons["カレンダー"].tap()
        app.buttons["shareButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["sharePreview"].waitForExistence(timeout: 5))
        attachScreenshot(named: "03-share")
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
