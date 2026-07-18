import XCTest
@testable import Oriel

final class Phase2AndBeyondTests: XCTestCase {
    func testHTTPSOnlyBlocksPlainHTTP() {
        let http = URL(string: "http://example.com/insecure")!
        let upgraded = HTTPSUpgrade.upgradeIfNeeded(http, enabled: true)
        XCTAssertTrue(upgraded.didUpgrade)
        XCTAssertEqual(upgraded.url.scheme, "https")
    }

    func testElementHidePersistence() async {
        await MainActor.run {
            let store = ElementHideStore()
            store.clear(host: "example.com")
            store.add(host: "example.com", cssSelector: ".cookie-banner")
            XCTAssertFalse(store.rules(forHost: "example.com").isEmpty)
            let script = store.injectionScript(forHost: "example.com")
            XCTAssertTrue(script.contains("cookie-banner"))
            store.clear(host: "example.com")
        }
    }

    func testProfilesCreateAndSelect() async {
        await MainActor.run {
            let store = ProfileStore()
            let before = store.profiles.count
            let created = store.create(name: "Work")
            XCTAssertEqual(store.profiles.count, before + 1)
            store.select(id: created.id)
            XCTAssertEqual(store.activeProfileID, created.id)
        }
    }

    func testOnboardingFlagDefaultsFalseThenPersists() async {
        await MainActor.run {
            let suiteName = "oriel.tests.onboarding.\(UUID().uuidString)"
            let suite = UserDefaults(suiteName: suiteName)!
            defer { suite.removePersistentDomain(forName: suiteName) }
            let settings = BrowserSettings(defaults: suite)
            XCTAssertFalse(settings.hasCompletedOnboarding)
            settings.hasCompletedOnboarding = true
            let reloaded = BrowserSettings(defaults: suite)
            XCTAssertTrue(reloaded.hasCompletedOnboarding)
        }
    }

    func testDefaultBrowserServiceGuidanceIsNonEmpty() async {
        await MainActor.run {
            let service = DefaultBrowserService()
            XCTAssertFalse(service.platformGuidance.isEmpty)
            service.refreshStatus()
            #if os(macOS)
            XCTAssertTrue(service.canSetAsDefaultDirectly)
            #else
            XCTAssertFalse(service.canSetAsDefaultDirectly)
            #endif
        }
    }

    func testSuggestionURLsExist() {
        XCTAssertNotNil(SearchEngine.duckDuckGo.suggestionURL(for: "test"))
        XCTAssertNotNil(SearchEngine.google.suggestionURL(for: "test"))
    }
}
