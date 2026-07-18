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
}
