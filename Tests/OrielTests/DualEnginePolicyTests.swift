import XCTest
@testable import Oriel

final class DualEnginePolicyTests: XCTestCase {
    @MainActor
    func testAvailableEnginesIncludeWebKit() {
        XCTAssertTrue(BrowserEngineKind.availableOnThisPlatform.contains(.webkit))
    }

    @MainActor
    func testResolvedWebKitStaysWebKit() {
        XCTAssertEqual(RenderingEnginePolicy.resolved(.webkit), .webkit)
    }

    @MainActor
    func testResolvedSmartFallsBackToWebKitWithoutHost() {
        XCTAssertEqual(RenderingEnginePolicy.resolved(.smart), .webkit)
    }

    @MainActor
    func testChromeDesktopUAWhenCompatible() {
        #if os(macOS)
        XCTAssertTrue(RenderingEnginePolicy.usesChromeDesktopUserAgent(.chromiumCompatibility))
        let ua = UserAgentPolicy.customUserAgent(
            for: URL(string: "https://example.com"),
            requestsDesktopSite: false,
            preferredEngine: .chromiumCompatibility
        )
        XCTAssertEqual(ua, UserAgentPolicy.chromeDesktop)
        #else
        // iOS must never leave WebKit for UA policy via preferred engine.
        XCTAssertEqual(RenderingEnginePolicy.resolved(.chromiumCompatibility), .webkit)
        XCTAssertFalse(RenderingEnginePolicy.usesChromeDesktopUserAgent(.chromiumCompatibility))
        #endif
    }

    @MainActor
    func testNativeFallsBackWhenFrameworkMissing() {
        #if os(macOS)
        if RenderingEnginePolicy.chromiumNativeStatus != .available {
            XCTAssertEqual(RenderingEnginePolicy.resolved(.chromiumNative), .chromiumCompatibility)
        }
        #else
        XCTAssertEqual(RenderingEnginePolicy.resolved(.chromiumNative), .webkit)
        XCTAssertEqual(RenderingEnginePolicy.chromiumNativeStatus, .unavailableOnIOS)
        #endif
    }

    func testPulseWallpapersHaveDisplayNames() {
        for paper in PulseWallpaper.allCases {
            XCTAssertFalse(paper.displayName.isEmpty)
        }
    }

    @MainActor
    func testSmartPicksWebKitForAppleHosts() {
        #if os(macOS)
        let policy = ChromiumSitePolicy()
        let engine = RenderingEnginePolicy.bestEngine(forHost: "appleid.apple.com", policy: policy)
        XCTAssertEqual(engine, .webkit)
        #endif
    }

    @MainActor
    func testSmartPicksChromiumPathForStubbornHosts() {
        #if os(macOS)
        let policy = ChromiumSitePolicy()
        policy.smartPrefersNativeBlink = true
        let engine = RenderingEnginePolicy.bestEngine(forHost: "discord.com", policy: policy)
        // Native when Blink path exists, otherwise Compatible — never WebKit for Discord.
        XCTAssertTrue(engine == .chromiumNative || engine == .chromiumCompatibility)
        XCTAssertNotEqual(engine, .webkit)
        #endif
    }

    @MainActor
    func testRealBlinkListIncludesNetflix() {
        XCTAssertTrue(ChromiumAutoSiteList.prefersRealBlink("www.netflix.com"))
        XCTAssertTrue(ChromiumAutoSiteList.matches("netflix.com"))
    }
}
