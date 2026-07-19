import XCTest
@testable import Oriel

final class DualEnginePolicyTests: XCTestCase {
    func testAvailableEnginesIncludeWebKit() {
        XCTAssertTrue(BrowserEngineKind.availableOnThisPlatform.contains(.webkit))
    }

    func testResolvedWebKitStaysWebKit() {
        XCTAssertEqual(RenderingEnginePolicy.resolved(.webkit), .webkit)
    }

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
}
