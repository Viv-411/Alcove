import XCTest

/// Walks through every screen the way a person would, checking the important
/// behaviour and saving screenshots (set TEST_RUNNER_SCREENSHOT_DIR to collect them).
final class AlcoveUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    // MARK: - Helpers

    private func launch(sample: Bool, extra: [String] = []) {
        app.launchArguments = ["-uiTesting"] + (sample ? ["-sampleData"] : []) + extra
        app.launch()
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { return }
        let suffix = ProcessInfo.processInfo.environment["SCREENSHOT_SUFFIX"] ?? ""
        try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name)\(suffix).png"))
    }

    private func tab(_ name: String) {
        let button = app.tabBars.buttons[name]
        XCTAssertTrue(button.waitForExistence(timeout: 5), "Missing tab \(name)")
        button.tap()
    }

    private func enterBarcode(_ code: String, confirm: String) {
        let enter = app.buttons["Enter barcode"].firstMatch
        if enter.waitForExistence(timeout: 2) {
            enter.tap()
        } else {
            app.buttons["Scan options"].tap()
            app.buttons["Enter barcode"].firstMatch.tap()
        }
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        field.typeText(code)
        app.alerts.buttons[confirm].tap()
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", fragment)).firstMatch
    }

    // MARK: - Tours

    func testStockedHomeTour() throws {
        launch(sample: true)

        XCTAssertTrue(app.staticTexts["To buy"].firstMatch.waitForExistence(timeout: 5))
        snap("01-home")
        app.swipeUp()
        snap("02-home-scrolled")

        app.staticTexts["Paneer"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["at home"].waitForExistence(timeout: 3))
        sleep(1)
        snap("03-detail")
        app.swipeUp()
        snap("04-detail-bottom")
        app.navigationBars.buttons.firstMatch.tap()

        tab("Inventory")
        snap("05-inventory")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Freezer'")).firstMatch.tap()
        snap("06-inventory-freezer")

        tab("Scan")
        snap("07-scan")

        // Known barcode → instant +1
        enterBarcode("8901063010017", confirm: "Add")
        XCTAssertTrue(text(containing: "Parle-G").waitForExistence(timeout: 3))
        snap("08-scan-in")

        // Unknown barcode → new product sheet with Open Food Facts lookup
        enterBarcode("3017620422003", confirm: "Add")
        XCTAssertTrue(app.navigationBars["New item"].waitForExistence(timeout: 5))
        _ = text(containing: "Found").waitForExistence(timeout: 10)
        snap("09-new-product")
        app.buttons["Save"].tap()
        snap("10-scan-after-new")

        app.buttons["Scan out"].tap()
        enterBarcode("8901063010017", confirm: "Remove")
        snap("11-scan-out")

        app.buttons["Receipt"].tap()
        snap("12-receipt")
        app.buttons["Cancel"].tap()

        tab("Search")
        snap("13-search")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        search.tap()
        search.typeText("rice")
        snap("14-search-rice")
        search.buttons.firstMatch.tap() // clear
        search.typeText("quinoa")
        snap("15-search-none")
    }

    func testSettings() {
        launch(sample: true)
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 3))
        snap("16-settings")
        app.buttons["settings.home"].tap()
        XCTAssertTrue(app.navigationBars["Sharma Home"].waitForExistence(timeout: 3))
        snap("17-home-detail")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Manage spaces'")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Spaces"].waitForExistence(timeout: 3))
        snap("18-spaces")
    }

    func testFirstLaunch() {
        app.launchArguments = ["-uiTesting", "-freshInstall"]
        app.launch()

        // Intro tour
        let next = app.buttons["tour.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        for page in 1...7 {
            sleep(1) // let the chips animate in
            snap(String(format: "40-tour-%02d", page))
            next.tap()
        }

        // Sign in
        let guest = app.buttons["signin.guest"]
        XCTAssertTrue(guest.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["signin.google"].exists || app.otherElements["signin.google"].exists)
        snap("50-sign-in")
        guest.tap()

        // Home setup
        let name = app.textFields["setup.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        snap("51-setup-name")
        app.buttons["setup.continue"].tap()
        XCTAssertTrue(app.staticTexts["Where do you keep food?"].waitForExistence(timeout: 3))
        app.buttons["Garage"].tap()          // deselect
        app.buttons["Spice rack"].tap()      // select
        let custom = app.textFields.firstMatch
        custom.tap()
        custom.typeText("Chest freezer\n")
        snap("52-setup-spaces")
        app.buttons["setup.continue"].tap()
        XCTAssertTrue(app.staticTexts["Who lives here?"].waitForExistence(timeout: 3))
        snap("53-setup-people")
        app.buttons["setup.continue"].tap()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 5))
        snap("54-new-home")
        tab("Inventory")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Chest freezer'")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Garage'")).firstMatch.exists)
        snap("55-new-inventory")
    }

    /// Run against a simulator that has the previous version's data installed
    /// (set TEST_RUNNER_UPGRADE_CHECK=1). Checks nothing is lost on upgrade.
    func testUpgradeKeepsExistingData() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["UPGRADE_CHECK"] == "1")
        app.launchArguments = []
        app.launch()

        let skip = app.buttons["tour.skip"]
        if skip.waitForExistence(timeout: 5) { skip.tap() }
        let guest = app.buttons["signin.guest"]
        if guest.waitForExistence(timeout: 5) { guest.tap() }

        XCTAssertTrue(app.textFields["setup.name"].waitForExistence(timeout: 5))
        app.buttons["setup.continue"].tap()
        // The old spaces are preselected.
        XCTAssertTrue(app.buttons["Garage"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Garage"].isSelected)
        snap("60-upgrade-spaces")
        app.buttons["setup.continue"].tap()
        app.buttons["setup.continue"].tap()

        // A real launch asks for notification permission; answer it.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        tab("Inventory")
        _ = app.staticTexts["Aloo Bhujia"].waitForExistence(timeout: 5)
        snap("61-upgrade-inventory")
        XCTAssertTrue(app.staticTexts["Aloo Bhujia"].exists)
        XCTAssertTrue(app.staticTexts["Frozen Parathas"].exists)
        snap("61-upgrade-inventory")
        tab("Home")
        XCTAssertTrue(app.staticTexts["28"].waitForExistence(timeout: 3), "Item count changed during upgrade")
    }

    func testEmptyHome() {
        launch(sample: false)
        snap("20-empty-home")
        tab("Inventory")
        snap("21-empty-inventory")
        tab("Scan")
        snap("22-empty-scan")
        tab("Search")
        snap("23-empty-search")
    }

    func testReceiptImport() throws {
        let fixture = try XCTUnwrap(ProcessInfo.processInfo.environment["RECEIPT_FIXTURE"])
        launch(sample: true, extra: ["-receiptFixture", fixture])
        tab("Scan")
        app.buttons["Receipt"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'items found'")).firstMatch
            .waitForExistence(timeout: 15))
        snap("30-receipt-review")
        app.swipeUp()
        snap("31-receipt-review-bottom")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Add'")).firstMatch.tap()
        tab("Inventory")
        snap("32-after-receipt")
    }
}
