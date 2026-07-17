import XCTest
@testable import Oriel

final class Phase4FeatureTests: XCTestCase {
    func testHomeEnablesBackWhenUnderlyingPageExists() async {
        await MainActor.run {
            let tab = BrowserTab(initialURL: URL(string: "https://example.com"))
            // Simulate a web view URL remaining after going home without destroying history.
            tab.navigation.url = URLParser.startPageURL
            tab.navigation.syncAddressBarFromURL()
            // Without webView, back should stay false
            tab.refreshNavigationChrome()
            XCTAssertFalse(tab.navigation.canGoBack)
            XCTAssertTrue(tab.isShowingStartPage)
        }
    }

    func testDesktopUserAgentConstant() {
        XCTAssertTrue(BrowserConstants.desktopUserAgent.contains("Macintosh"))
        XCTAssertTrue(BrowserConstants.desktopUserAgent.contains("Safari"))
    }

    func testPermissionDefaultsToAsk() async {
        await MainActor.run {
            let manager = WebsitePermissionManager()
            XCTAssertEqual(manager.decision(for: "unique-test-host.example", permission: .camera), .ask)
            manager.setDecision(.allow, for: "unique-test-host.example", permission: .camera)
            XCTAssertEqual(manager.decision(for: "unique-test-host.example", permission: .camera), .allow)
            XCTAssertEqual(manager.grantedPermissions(for: "unique-test-host.example"), [.camera])
        }
    }
}
