import XCTest
@testable import Oriel

final class Phase6SearchSettingsTests: XCTestCase {
    func testGoogleSearchURL() {
        let url = SearchEngine.google.searchURL(for: "oriel browser")
        XCTAssertEqual(url.host, "www.google.com")
        XCTAssertTrue(url.query?.contains("q=oriel") == true || url.query?.contains("oriel") == true)
        XCTAssertFalse(url.query?.contains("client=safari") == true)
        XCTAssertFalse(url.query?.contains("udm=14") == true)
        XCTAssertEqual(SearchEngine.google.addressBarPlaceholder, "Search with Google or enter address")
    }

    func testResolveUsesSelectedEngine() {
        let google = URLParser.resolve("swift concurrency", searchEngine: .google)
        XCTAssertEqual(google.host, "www.google.com")

        let ddg = URLParser.resolve("swift concurrency", searchEngine: .duckDuckGo)
        XCTAssertEqual(ddg.host, "duckduckgo.com")
    }

    func testGoogleHostsUseChromeLikeUserAgent() {
        let google = URL(string: "https://www.google.com/search?q=test")!
        let ua = UserAgentPolicy.customUserAgent(for: google, requestsDesktopSite: false)
        XCTAssertNotNil(ua)
        XCTAssertTrue(ua?.contains("Chrome/") == true)
        XCTAssertFalse(ua?.contains("Version/18") == true)

        let example = URL(string: "https://example.com")!
        XCTAssertNil(UserAgentPolicy.customUserAgent(for: example, requestsDesktopSite: false))
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
