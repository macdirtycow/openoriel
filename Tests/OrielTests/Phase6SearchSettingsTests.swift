import XCTest
@testable import Oriel

final class Phase6SearchSettingsTests: XCTestCase {
    func testGoogleSearchURL() {
        let url = SearchEngine.google.searchURL(for: "oriel browser")
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertTrue(url.query?.contains("oriel") == true)
        XCTAssertEqual(SearchEngine.google.addressBarPlaceholder, "Search with Google or enter address")
    }

    func testResolveUsesSelectedEngine() {
        let google = URLParser.resolve("swift concurrency", searchEngine: .google)
        XCTAssertEqual(google.host, "www.google.com")

        let ddg = URLParser.resolve("swift concurrency", searchEngine: .duckDuckGo)
        XCTAssertEqual(ddg.host, "duckduckgo.com")
    }

    func testSettingsPersistSearchEngine() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "oriel.tests.search.\(UUID().uuidString)")!
            let settings = BrowserSettings(defaults: defaults)
            settings.searchEngine = .google
            let reloaded = BrowserSettings(defaults: defaults)
            XCTAssertEqual(reloaded.searchEngine, .google)
        }
    }
}
