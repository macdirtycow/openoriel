import XCTest
@testable import Oriel

final class ChromeWebStoreAPITests: XCTestCase {
    func testValidExtensionID() {
        XCTAssertTrue(ChromeWebStoreAPI.isValidExtensionID("cjpalhdlnbpafiamejdnhcphjbkeiagm"))
        XCTAssertTrue(ChromeWebStoreAPI.isValidExtensionID("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"))
        XCTAssertFalse(ChromeWebStoreAPI.isValidExtensionID("not-an-id"))
        XCTAssertFalse(ChromeWebStoreAPI.isValidExtensionID("abcdefghijklmnopqrstuvwxyzabcdef"))
        XCTAssertFalse(ChromeWebStoreAPI.isValidExtensionID("ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEF"))
    }

    func testExtensionIDFromStoreURL() {
        let url = URL(string: "https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm")!
        XCTAssertEqual(
            ChromeWebStoreAPI.extensionID(fromStoreURL: url),
            "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        )
    }

    func testDownloadURL() {
        let id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        let url = ChromeWebStoreAPI.downloadURL(forExtensionID: id)
        XCTAssertEqual(url?.host, "clients2.google.com")
        XCTAssertTrue(url?.absoluteString.contains(id) == true)
        XCTAssertTrue(url?.absoluteString.contains("acceptformat=crx3") == true)
    }

    func testInstallURLParsing() {
        let id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"
        let url = ChromeWebStoreAPI.installURL(forExtensionID: id)!
        XCTAssertEqual(ChromeWebStoreAPI.extensionID(fromInstallURL: url), id)
        let bare = URL(string: "oriel-extension://\(id)")!
        XCTAssertEqual(ChromeWebStoreAPI.extensionID(fromInstallURL: bare), id)
    }

    func testBridgeScriptsMentionPhoneCompatWorkaround() {
        // Regression guard: keep the mobile CWS workaround wired into the injected scripts.
        XCTAssertTrue(ChromeWebStoreBridge.chromeAPIStubSource.contains("maxTouchPoints"))
        XCTAssertTrue(ChromeWebStoreBridge.chromeAPIStubSource.contains("MacIntel"))
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("not compatible with"))
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("oriel-cws-tip"))
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("Add to Oriel"))
        // Localized “Toevoegen aan Chrome” must be rewritten too (common on Dutch iOS).
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("Toevoegen"))
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("isInstallChromeLabel"))
    }
}
