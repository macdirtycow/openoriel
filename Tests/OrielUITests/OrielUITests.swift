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
}
