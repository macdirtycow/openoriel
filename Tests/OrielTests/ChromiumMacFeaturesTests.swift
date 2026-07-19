import XCTest
@testable import Oriel

@MainActor
final class ChromiumMacFeaturesTests: XCTestCase {
    func testAutoListMatchesMeet() {
        XCTAssertTrue(ChromiumAutoSiteList.matches("meet.google.com"))
        XCTAssertTrue(ChromiumAutoSiteList.matches("app.meet.google.com"))
        XCTAssertFalse(ChromiumAutoSiteList.matches("example.com"))
    }

    func testWebKitPreferredHosts() {
        XCTAssertTrue(ChromiumAutoSiteList.prefersWebKitIdentity("appleid.apple.com"))
        XCTAssertTrue(ChromiumAutoSiteList.prefersWebKitIdentity("accounts.google.com"))
        XCTAssertFalse(ChromiumAutoSiteList.prefersWebKitIdentity("meet.google.com"))
    }

    func testSmartPicksChromiumForMeetAndWebKitForApple() {
        let policy = ChromiumSitePolicy()
        #if os(macOS)
        XCTAssertEqual(
            RenderingEnginePolicy.resolve(global: .smart, tabOverride: nil, host: "meet.google.com", policy: policy),
            .chromiumCompatibility
        )
        XCTAssertEqual(
            RenderingEnginePolicy.resolve(global: .smart, tabOverride: nil, host: "www.apple.com", policy: policy),
            .webkit
        )
        XCTAssertEqual(
            RenderingEnginePolicy.resolve(global: .smart, tabOverride: nil, host: "example.com", policy: policy),
            .webkit
        )
        #else
        XCTAssertEqual(
            RenderingEnginePolicy.resolve(global: .smart, tabOverride: nil, host: "meet.google.com", policy: policy),
            .webkit
        )
        #endif
    }

    func testTwoHostsCanResolveDifferentlyUnderSmart() {
        let policy = ChromiumSitePolicy()
        let meet = RenderingEnginePolicy.resolve(global: .smart, tabOverride: nil, host: "teams.microsoft.com", policy: policy)
        let bbc = RenderingEnginePolicy.resolve(global: .smart, tabOverride: nil, host: "bbc.com", policy: policy)
        #if os(macOS)
        XCTAssertEqual(meet, .chromiumCompatibility)
        XCTAssertEqual(bbc, .webkit)
        XCTAssertNotEqual(meet, bbc)
        #else
        XCTAssertEqual(meet, .webkit)
        XCTAssertEqual(bbc, .webkit)
        #endif
    }

    func testTabOverrideBeatsSmart() {
        let policy = ChromiumSitePolicy()
        let engine = RenderingEnginePolicy.resolve(
            global: .smart,
            tabOverride: .webkit,
            host: "meet.google.com",
            policy: policy
        )
        XCTAssertEqual(engine, .webkit)
    }

    func testForceWebKitBeatsAutoList() {
        let policy = ChromiumSitePolicy()
        policy.autoChromiumForStubbornSites = true
        policy.setPreference(.forceWebKit, forHost: "meet.google.com")
        let engine = RenderingEnginePolicy.resolve(
            global: .webkit,
            tabOverride: nil,
            host: "meet.google.com",
            policy: policy
        )
        XCTAssertEqual(engine, .webkit)
    }

    func testIdentityScriptIsNonEmpty() {
        XCTAssertTrue(ChromiumIdentityScript.source.contains("userAgentData"))
        XCTAssertTrue(ChromiumIdentityScript.source.contains("Chromium"))
    }

    func testSmartIsAvailableOnMacOnly() {
        #if os(macOS)
        XCTAssertTrue(BrowserEngineKind.availableOnThisPlatform.contains(.smart))
        #else
        XCTAssertFalse(BrowserEngineKind.availableOnThisPlatform.contains(.smart))
        #endif
    }
}
