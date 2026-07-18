import XCTest
@testable import Oriel

final class ThemeAndPrivacyStatsTests: XCTestCase {
    func testBackgroundThemeLocksReadableColorScheme() {
        XCTAssertEqual(BrowserBackgroundTheme.midnight.resolvedColorScheme(system: .light), .dark)
        XCTAssertEqual(BrowserBackgroundTheme.paper.resolvedColorScheme(system: .dark), .light)
        XCTAssertEqual(BrowserBackgroundTheme.soft.resolvedColorScheme(system: .dark), .dark)
    }

    func testAccentAndBackgroundThemesPersist() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "oriel.tests.theme.\(UUID().uuidString)")!
            let settings = BrowserSettings(defaults: defaults)
            settings.accentTheme = .ocean
            settings.backgroundTheme = .aurora
            let reloaded = BrowserSettings(defaults: defaults)
            XCTAssertEqual(reloaded.accentTheme, .ocean)
            XCTAssertEqual(reloaded.backgroundTheme, .aurora)
        }
    }

    func testCookieRelatedHostClassification() {
        XCTAssertTrue(
            PrivacyStats.looksCookieRelated(URL(string: "https://www.googleadservices.com/pagead/cookie")!)
        )
        XCTAssertTrue(
            PrivacyStats.looksCookieRelated(URL(string: "https://cdn.cookiebot.com/uc.js")!)
        )
        XCTAssertFalse(
            PrivacyStats.looksCookieRelated(URL(string: "https://example.com/about")!)
        )
    }

    func testBlockedRequestIncrementsCookieCounter() async {
        await MainActor.run {
            let fileName = "privacy-stats-test-\(UUID().uuidString).json"
            let stats = PrivacyStats(fileName: fileName)
            let beforeTrackers = stats.blockedRequestsSession
            let beforeCookies = stats.cookiesBlockedSession
            stats.recordBlockedRequest(url: URL(string: "https://doubleclick.net/pixel"))
            XCTAssertEqual(stats.blockedRequestsSession, beforeTrackers + 1)
            XCTAssertEqual(stats.cookiesBlockedSession, beforeCookies + 1)
            stats.recordBlockedRequest(url: URL(string: "https://cdn.example.com/script.js"))
            XCTAssertEqual(stats.blockedRequestsSession, beforeTrackers + 2)
            XCTAssertEqual(stats.cookiesBlockedSession, beforeCookies + 1)
        }
    }

    func testSessionCountersPersistAcrossRelaunch() async {
        await MainActor.run {
            let fileName = "privacy-stats-persist-\(UUID().uuidString).json"
            let first = PrivacyStats(fileName: fileName)
            first.recordBlockedRequest(url: URL(string: "https://doubleclick.net/pixel"))
            first.recordBlockedRequest(url: URL(string: "https://cdn.example.com/ads.js"))
            first.recordHTTPSUpgrade()
            let sessionBlocked = first.blockedRequestsSession
            let sessionCookies = first.cookiesBlockedSession
            let sessionHTTPS = first.httpsUpgradesSession
            let sessionTime = first.timeSavedMillisecondsSession
            let lifetimeBlocked = first.blockedRequestsLifetime

            let reloaded = PrivacyStats(fileName: fileName)
            XCTAssertEqual(reloaded.blockedRequestsSession, sessionBlocked)
            XCTAssertEqual(reloaded.cookiesBlockedSession, sessionCookies)
            XCTAssertEqual(reloaded.httpsUpgradesSession, sessionHTTPS)
            XCTAssertEqual(reloaded.timeSavedMillisecondsSession, sessionTime)
            XCTAssertEqual(reloaded.blockedRequestsLifetime, lifetimeBlocked)

            reloaded.resetSessionCounters()
            let afterReset = PrivacyStats(fileName: fileName)
            XCTAssertEqual(afterReset.blockedRequestsSession, 0)
            XCTAssertEqual(afterReset.cookiesBlockedSession, 0)
            XCTAssertEqual(afterReset.httpsUpgradesSession, 0)
            XCTAssertEqual(afterReset.timeSavedMillisecondsSession, 0)
            XCTAssertEqual(afterReset.blockedRequestsLifetime, lifetimeBlocked)
        }
    }
}
