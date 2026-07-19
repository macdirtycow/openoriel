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

    func testGoogleHostsUseSafariUserAgent() {
        let google = URL(string: "https://www.google.com/search?q=test")!
        // Spoofing Chrome on WebKit triggers bot checks — stay on Safari UA.
        XCTAssertNil(UserAgentPolicy.customUserAgent(for: google, requestsDesktopSite: false))

        let example = URL(string: "https://example.com")!
        XCTAssertNil(UserAgentPolicy.customUserAgent(for: example, requestsDesktopSite: false))

        let desktop = UserAgentPolicy.customUserAgent(for: example, requestsDesktopSite: true)
        XCTAssertEqual(desktop, UserAgentPolicy.safariDesktop)
    }

    func testChromeWebStoreUsesDesktopChromeUserAgent() {
        let store = URL(string: "https://chromewebstore.google.com/detail/foo/cjpalhdlnbpafiamejdnhcphjbkeiagm")!
        XCTAssertTrue(UserAgentPolicy.isChromeWebStoreHost(store.host))
        XCTAssertEqual(
            UserAgentPolicy.customUserAgent(for: store, requestsDesktopSite: false),
            UserAgentPolicy.chromeDesktop
        )
        // Search stays on Safari — only the store host is overridden.
        XCTAssertFalse(UserAgentPolicy.isChromeWebStoreHost("www.google.com"))
    }

    func testFirefoxAddonsUsesDesktopFirefoxUserAgent() {
        let amo = URL(string: "https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/")!
        XCTAssertTrue(UserAgentPolicy.isFirefoxAddonsHost(amo.host))
        XCTAssertTrue(UserAgentPolicy.isExtensionStoreHost(amo.host))
        XCTAssertEqual(
            UserAgentPolicy.customUserAgent(for: amo, requestsDesktopSite: false),
            UserAgentPolicy.firefoxDesktop
        )
        XCTAssertFalse(UserAgentPolicy.isFirefoxAddonsHost("www.mozilla.org"))
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
