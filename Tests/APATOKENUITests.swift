import XCTest

final class APATOKENUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments = ["-TestingMode", "YES", "-LanguageTag", "en"]
        app.launch()
    }

    func testRechargeKeyboardHistoryAndRelaunch() throws {
        app.tabBars.buttons["Settings"].tap()
        app.buttons["Testing tools"].tap()
        let reset = app.buttons["Reset testing data"]
        if !reset.isHittable { app.swipeUp() }
        reset.tap()
        app.buttons["Reset testing data"].lastMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.tabBars.buttons["Recharge"].tap()
        let input = app.textFields["tokenInput"]
        input.tap()
        input.typeText("00000000000000000000")
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        app.buttons["hideKeyboard"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        input.tap()
        app.navigationBars.staticTexts["Recharge"].tap()
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        input.tap()
        app.buttons["applyToken"].tap()
        XCTAssertTrue(app.staticTexts["transactionError"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.keyboards.firstMatch.exists)
        screenshot("Rejected-token")
        app.buttons["transactionDone"].tap()
        app.buttons["testTokens"].tap()
        app.buttons["generateToken"].tap()
        app.buttons["useTestToken"].firstMatch.tap()
        app.buttons["applyToken"].tap()
        XCTAssertTrue(app.buttons["transactionDone"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["transactionStatus"].label, "Success!")
        screenshot("Recharge-success")
        app.buttons["transactionDone"].tap()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["90000001"].firstMatch.waitForExistence(timeout: 3))
        screenshot("Recharge-history")
        app.tabBars.buttons["Readings"].tap()
        app.buttons["readCredits"].tap()
        app.tabBars.buttons["History"].tap()
        app.segmentedControls["historyTabs"].buttons["Readings"].tap()
        XCTAssertTrue(app.staticTexts["90000001"].firstMatch.exists)
        app.terminate()
        app.launch()
        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.staticTexts["90000001"].firstMatch.waitForExistence(timeout: 3))
    }

    func testLanguageSwitchingAcrossTabsAndSheets() throws {
        for (tag, settings, recharge, history, readings, language) in [
            ("pl", "Ustawienia", "Doładowanie", "Historia", "Odczyty", "Język"),
            ("fr", "Paramètres", "Recharge", "Historique", "Relevés", "Langue"),
            ("en", "Settings", "Recharge", "History", "Readings", "Language")
        ] {
            app.tabBars.buttons.element(boundBy: 3).tap()
            app.buttons["languageSettings"].tap()
            app.buttons["language-" + tag].tap()
            XCTAssertTrue(app.navigationBars[language].exists)
            app.navigationBars.buttons.element(boundBy: 0).tap()
            XCTAssertTrue(app.navigationBars[settings].exists)
            assertNoRawKeys()
            app.tabBars.buttons[recharge].tap()
            XCTAssertTrue(app.navigationBars[recharge].exists)
            screenshot("Recharge-" + tag)
            assertNoRawKeys()
            app.buttons["testTokens"].tap()
            assertNoRawKeys()
            app.navigationBars.buttons.element(boundBy: 0).tap()
            app.tabBars.buttons[history].tap()
            XCTAssertTrue(app.navigationBars[history].exists)
            assertNoRawKeys()
            app.tabBars.buttons[readings].tap()
            XCTAssertTrue(app.navigationBars[readings].exists)
            assertNoRawKeys()
        }
    }

    private func assertNoRawKeys() {
        for element in app.staticTexts.allElementsBoundByIndex + app.buttons.allElementsBoundByIndex {
            XCTAssertNil(element.label.range(of: #"\b(?:txt|msg)[A-Z][A-Za-z]+"#, options: .regularExpression), element.label)
        }
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
