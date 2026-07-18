import XCTest

final class OrielUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsStartPage() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["Oriel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["openoriel.com"].exists)
    }

    func testOpenShieldsSheet() throws {
        let app = XCUIApplication()
        app.launch()

        // Prefer accessibility label on the shield button.
        let shields = app.buttons["Privacy Shields"]
        if shields.waitForExistence(timeout: 3) {
            shields.tap()
        } else {
            // Fallback: More menu → Shields
            let more = app.buttons["More"]
            XCTAssertTrue(more.waitForExistence(timeout: 3))
            more.tap()
            app.buttons["Shields"].tap()
        }

        XCTAssertTrue(app.navigationBars["Shields"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Dashboard"].exists || app.staticTexts["Blocked"].exists)
        app.buttons["Done"].tap()
    }
}
