import XCTest
@testable import Oriel

final class Phase3PrivacyTests: XCTestCase {
    func testHTTPSUpgrade() {
        let http = URL(string: "http://example.com/path")!
        let result = HTTPSUpgrade.upgradeIfNeeded(http, enabled: true)
        XCTAssertTrue(result.didUpgrade)
        XCTAssertEqual(result.url.scheme, "https")

        let localhost = URL(string: "http://localhost:8080")!
        let local = HTTPSUpgrade.upgradeIfNeeded(localhost, enabled: true)
        XCTAssertFalse(local.didUpgrade)

        let disabled = HTTPSUpgrade.upgradeIfNeeded(http, enabled: false)
        XCTAssertFalse(disabled.didUpgrade)
    }

    func testContentRuleValidation() throws {
        let json = """
        [
          {
            "trigger": { "url-filter": ".*doubleclick\\\\.net" },
            "action": { "type": "block" }
          }
        ]
        """.data(using: .utf8)!
        let rules = try ContentRuleListValidator.validate(json)
        XCTAssertEqual(rules.count, 1)
        let hints = ContentRuleListValidator.blockedHostHints(from: rules)
        XCTAssertTrue(hints.contains { $0.contains("doubleclick.net") })
    }

    func testContentRuleValidationRejectsGarbage() {
        let data = Data("{\"no\":\"array\"}".utf8)
        XCTAssertThrowsError(try ContentRuleListValidator.validate(data))
    }

    func testPrivateTabsExcludedFromSessionSnapshot() async {
        await MainActor.run {
            let manager = TabManager(searchEngine: .duckDuckGo, restoring: nil)
            _ = manager.createPrivateTab(select: true)
            XCTAssertEqual(manager.privateTabs.count, 1)
            let snapshot = manager.makeSessionSnapshot()
            XCTAssertTrue(snapshot.tabs.allSatisfy { !$0.isPrivate })
        }
    }

    func testPrivacySettingsPerSite() async {
        await MainActor.run {
            let settings = PrivacySettings()
            settings.setContentBlocking(false, forHost: "example.com")
            XCTAssertFalse(settings.effectiveContentBlocking(forHost: "example.com"))
            XCTAssertTrue(settings.effectiveContentBlocking(forHost: "other.com"))
        }
    }
}
