import XCTest

@MainActor
final class SwimFinderUITests: XCTestCase {
    private func keepScreenshot(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func launch(seeded: Bool = false, contentSize: String? = nil, freeTier: Bool = false, seedFreeAthleteLimit: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if seeded { app.launchArguments.append("-seedHistory") }
        if freeTier { app.launchArguments.append("-uiTestingFree") }
        if seedFreeAthleteLimit { app.launchArguments.append("-seedFreeAthleteLimit") }
        if let contentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize]
        }
        app.launch()
        return app
    }

    func testFreeTierShowsPlusAndLimitsThirdAthlete() {
        let app = launch(freeTier: true, seedFreeAthleteLimit: true)
        let plus = app.buttons["home.plus"]
        XCTAssertTrue(plus.waitForExistence(timeout: 5))
        plus.tap()
        XCTAssertTrue(app.navigationBars["Plus会員"].waitForExistence(timeout: 5))
        app.buttons["閉じる"].tap()

        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.buttons["settings.notifications.locked"].waitForExistence(timeout: 5))
        app.tabBars.buttons["ホーム"].tap()

        app.buttons["home.playerSearch"].tap()
        let field = app.textFields["player.queryField"]
        field.tap(); field.typeText("架空 太郎")
        app.buttons["player.search"].tap()
        app.staticTexts["架空 太郎"].firstMatch.tap()
        XCTAssertTrue(app.buttons["player.favorite"].waitForExistence(timeout: 5))
        app.buttons["player.favorite"].tap()
        XCTAssertTrue(app.navigationBars["Plus会員"].waitForExistence(timeout: 5))
    }

    func testHomeShowsSearchEntries() {
        let app = launch()
        XCTAssertTrue(app.otherElements["home.sourceDisclaimer"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["home.officialSourceLink"].exists)
        XCTAssertTrue(app.buttons["home.playerSearch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["home.affiliationSearch"].exists)
        XCTAssertTrue(app.buttons["home.meetSearch"].exists)
        XCTAssertTrue(app.staticTexts["home.emptyRecents"].exists)
    }

    func testCaptureAppStoreScreenshots() {
        let app = launch(seeded: true)
        XCTAssertTrue(app.navigationBars["SwimScope"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "01-home")

        app.buttons["home.playerSearch"].tap()
        let field = app.textFields["player.queryField"]
        field.tap(); field.typeText("架空 太郎")
        app.buttons["player.search"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "02-player-search")

        app.staticTexts["架空 太郎"].firstMatch.tap()
        let eventPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '種目'")).firstMatch
        XCTAssertTrue(eventPicker.waitForExistence(timeout: 5))
        eventPicker.tap()
        app.buttons["100m 自由形（長水路）"].tap()
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["player.resultTrend"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "03-result-growth")

        app.tabBars.buttons["マイ選手"].tap()
        let raceDay = app.buttons["athleteHub.raceDay"]
        XCTAssertTrue(raceDay.waitForExistence(timeout: 5))
        raceDay.tap()
        XCTAssertTrue(app.staticTexts["大会当日モード"].waitForExistence(timeout: 5))
        keepScreenshot(app, name: "04-race-day")
    }

    func testPlayerSearchShowsNativeResultsAndRecordsHistory() {
        let app = launch()
        app.buttons["home.playerSearch"].tap()

        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let searchButton = app.buttons["player.search"]
        XCTAssertFalse(searchButton.isEnabled, "空欄では検索できない")

        field.tap()
        field.typeText("  架空\u{3000}太郎 ")
        XCTAssertTrue(searchButton.isEnabled)
        searchButton.tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["officialURLLabel"].exists)

        app.staticTexts["架空 太郎"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["これまでの成績"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["player.selectEventHint"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["前回との差"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["サンプル市民水泳大会"].firstMatch.exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let recent = app.descendants(matching: .any)["recent.player"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        XCTAssertTrue(recent.label.contains("架空 太郎"))
    }

    func testMeetSearchWithYear() {
        let app = launch()
        app.buttons["home.meetSearch"].tap()
        let field = app.textFields["meet.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["meet.prefecturePicker"].exists)
        XCTAssertTrue(app.buttons["meet.statusPicker"].exists)
        XCTAssertTrue(app.buttons["meet.waterwayPicker"].exists)
        field.tap()
        field.typeText("サンプル市民水泳大会")
        app.buttons["meet.search"].tap()
        XCTAssertTrue(app.staticTexts["サンプル市民水泳大会"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["officialURLLabel"].exists)
        app.staticTexts["サンプル市民水泳大会"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["男子 100m 自由形"].waitForExistence(timeout: 5))
        app.staticTexts["男子 100m 自由形"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["51.79"].exists)
    }

    func testRecentSearchCanBeReused() {
        let app = launch(seeded: true)
        let recent = app.descendants(matching: .any)["recent.player"].firstMatch
        app.swipeUp()
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        recent.tap()
        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse((field.value as? String ?? "").isEmpty)
    }

    func testTooShortQueryShowsErrorNotZeroResults() {
        let app = launch()
        app.buttons["home.playerSearch"].tap()
        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("山")
        XCTAssertFalse(app.buttons["player.search"].isEnabled)
        XCTAssertFalse(app.staticTexts["officialURLLabel"].exists)
    }

    func testPlayerSearchByClubOrSchoolName() {
        let app = launch()
        app.buttons["home.affiliationSearch"].tap()
        let affiliation = app.textFields["player.affiliationField"]
        XCTAssertTrue(affiliation.waitForExistence(timeout: 5))
        affiliation.tap()
        affiliation.typeText("サンプルSC")
        app.buttons["player.search"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["見本 花子"].firstMatch.exists)
    }

    func testAffiliationHistoryRestoresAffiliationField() {
        let app = launch()
        app.buttons["home.affiliationSearch"].tap()
        let affiliation = app.textFields["player.affiliationField"]
        XCTAssertTrue(affiliation.waitForExistence(timeout: 5))
        affiliation.tap()
        affiliation.typeText("サンプルSC")
        app.buttons["player.search"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        let recent = app.descendants(matching: .any)["recent.affiliation"].firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        recent.tap()
        let restored = app.textFields["player.affiliationField"]
        XCTAssertTrue(restored.waitForExistence(timeout: 5))
        XCTAssertEqual(restored.value as? String, "サンプルSC")
    }

    func testPlayerCanBeFavoritedAndOpenedNatively() {
        let app = launch()
        app.buttons["home.playerSearch"].tap()
        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("架空 太郎")
        app.buttons["player.search"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
        app.staticTexts["架空 太郎"].firstMatch.tap()
        let favorite = app.buttons["player.favorite"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        favorite.tap()
        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
    }

    func testClearHistoryFromSettings() {
        let app = launch(seeded: true)
        app.swipeUp()
        XCTAssertTrue(app.descendants(matching: .any)["recent.player"].firstMatch.waitForExistence(timeout: 5))

        app.tabBars.buttons["設定"].tap()
        let clear = app.buttons["settings.clearHistory"]
        XCTAssertTrue(clear.waitForExistence(timeout: 5))
        clear.tap()
        app.buttons["削除"].firstMatch.tap()

        app.tabBars.buttons["ホーム"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["home.emptyRecents"].waitForExistence(timeout: 5))
    }

    func testAccessibilityExtraLargeTextStillNavigates() {
        let app = launch(contentSize: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge")
        XCTAssertTrue(app.buttons["home.playerSearch"].waitForExistence(timeout: 5))
        app.buttons["home.playerSearch"].tap()
        XCTAssertTrue(app.textFields["player.queryField"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["player.search"].exists)
    }

    func testMyAthletesShowsLatestResultAndRaceDay() {
        let app = launch(seeded: true)
        app.tabBars.buttons["マイ選手"].tap()
        XCTAssertTrue(app.staticTexts["架空 太郎"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["51.79"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["前回から 0.31秒短縮"].exists)
        XCTAssertTrue(app.staticTexts["サンプル市民水泳大会"].exists)
        let raceDay = app.buttons["athleteHub.raceDay"]
        XCTAssertTrue(raceDay.exists)
        raceDay.tap()
        XCTAssertTrue(app.staticTexts["泳道・予定時刻"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["raceDay.unavailableSchedule"].exists)

        app.buttons["raceDay.add"].tap()
        app.buttons["racePlan.athlete"].tap()
        app.buttons["架空 太郎"].tap()
        let plannedEvent = app.textFields["racePlan.event"]
        plannedEvent.tap(); plannedEvent.typeText("100m 自由形")
        app.textFields["racePlan.heat"].tap(); app.textFields["racePlan.heat"].typeText("3")
        app.buttons["racePlan.keyboardDone"].tap()
        let reminder = app.switches["racePlan.enableReminder"]
        XCTAssertTrue(reminder.exists)
        if !reminder.isHittable { app.swipeUp() }
        XCTAssertTrue(reminder.waitForExistence(timeout: 3))
        reminder.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        XCTAssertEqual(reminder.value as? String, "1")
        app.buttons["racePlan.save"].tap()
        XCTAssertTrue(app.staticTexts["100m 自由形"].waitForExistence(timeout: 5))
        let details = app.descendants(matching: .any)["racePlan.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        XCTAssertTrue(details.label.contains("3組"))
        XCTAssertTrue(app.descendants(matching: .any)["racePlan.countdown"].exists)
        let reminderStatus = app.staticTexts["30分前に通知"]
        if !reminderStatus.exists { app.swipeUp() }
        XCTAssertTrue(reminderStatus.waitForExistence(timeout: 5))

        let edit = app.buttons.matching(identifier: "racePlan.edit").firstMatch
        if !edit.isHittable { app.swipeDown() }
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.navigationBars["当日予定を編集"].waitForExistence(timeout: 5))
        let editedHeat = app.textFields["racePlan.heat"]
        XCTAssertEqual(editedHeat.value as? String, "3")
        editedHeat.tap()
        editedHeat.typeText(XCUIKeyboardKey.delete.rawValue)
        editedHeat.typeText("5")
        app.buttons["racePlan.keyboardDone"].tap()
        app.buttons["racePlan.save"].tap()
        XCTAssertTrue(details.waitForExistence(timeout: 5))
        XCTAssertTrue(details.label.contains("5組"))
    }

    func testFamilyViewComparesEachAthleteToThemselves() {
        let app = launch(seeded: true)
        app.tabBars.buttons["マイ選手"].tap()
        let family = app.buttons["athleteHub.family"]
        XCTAssertTrue(family.waitForExistence(timeout: 5))
        family.tap()
        XCTAssertTrue(app.staticTexts["順位ではなく、それぞれの選手が自分の過去からどれだけ前進したかを表示します。"].waitForExistence(timeout: 5))
        let improvement = app.descendants(matching: .any)["family.improvement"]
        XCTAssertTrue(improvement.waitForExistence(timeout: 5))
        XCTAssertTrue(improvement.label.contains("0.31秒"))
    }

    func testGoalAndPrivateShareCardControls() {
        let app = launch()
        app.buttons["home.playerSearch"].tap()
        let field = app.textFields["player.queryField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("架空 太郎")
        app.buttons["player.search"].tap()
        app.staticTexts["架空 太郎"].firstMatch.tap()

        let eventPicker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '種目'")).firstMatch
        XCTAssertTrue(eventPicker.waitForExistence(timeout: 5))
        eventPicker.tap()
        app.buttons["100m 自由形（長水路）"].tap()
        app.swipeUp()

        let goal = app.buttons["player.goal"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        let time = app.textFields["goal.time"]
        time.tap(); time.typeText("51.50")
        app.buttons["goal.save"].tap()
        let progress = app.descendants(matching: .any)["player.goalProgress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("0.29秒"))

        let share = app.buttons["player.shareCard"]
        XCTAssertTrue(share.exists)
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["share.preview"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["選手名を隠す"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["大会名を隠す"].exists)
        XCTAssertTrue(app.switches["日付を隠す"].exists)
        XCTAssertTrue(app.switches["順位を隠す"].exists)
        XCTAssertTrue(app.buttons["share.create"].exists)
    }

    func testResultNotificationSettingIsAvailable() {
        let app = launch()
        app.tabBars.buttons["設定"].tap()
        XCTAssertTrue(app.switches["settings.notifications"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["通知権限"].exists)
        XCTAssertTrue(app.buttons["settings.checkResultsNow"].exists)
        XCTAssertFalse(app.buttons["settings.checkResultsNow"].isEnabled)
    }

    func testEmptyMyAthletesOffersDirectAddFlow() {
        let app = launch()
        app.tabBars.buttons["マイ選手"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["athleteHub.empty"].waitForExistence(timeout: 5))
        let add = app.buttons["athleteHub.add"]
        XCTAssertTrue(add.exists)
        add.tap()
        XCTAssertTrue(app.textFields["player.queryField"].waitForExistence(timeout: 5))
    }

    func testAthleteNicknameAndGroupCanBeManaged() {
        let app = launch(seeded: true)
        app.tabBars.buttons["マイ選手"].tap()
        let manage = app.buttons["athleteHub.manage"]
        XCTAssertTrue(manage.waitForExistence(timeout: 5))
        manage.tap()
        app.staticTexts["架空 太郎"].firstMatch.tap()
        let nickname = app.textFields["athletePreference.nickname"]
        nickname.tap(); nickname.typeText("太郎くん")
        let group = app.textFields["athletePreference.group"]
        group.tap(); group.typeText("家族")
        app.buttons["athletePreference.save"].tap()
        XCTAssertTrue(app.staticTexts["太郎くん"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS '家族'")).firstMatch.exists)
    }

    func testClearAllLocalDataRemovesHistoryFavoritesAndAthletes() {
        let app = launch(seeded: true)
        app.tabBars.buttons["設定"].tap()
        let clearAll = app.buttons["settings.clearAllData"]
        XCTAssertTrue(clearAll.waitForExistence(timeout: 5))
        clearAll.tap()
        app.buttons["settings.clearAllData.confirm"].firstMatch.tap()

        app.tabBars.buttons["お気に入り"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["favorites.empty"].waitForExistence(timeout: 5))
        app.tabBars.buttons["マイ選手"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["athleteHub.empty"].waitForExistence(timeout: 5))
        app.tabBars.buttons["ホーム"].tap()
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["home.emptyRecents"].waitForExistence(timeout: 5))
    }
}
