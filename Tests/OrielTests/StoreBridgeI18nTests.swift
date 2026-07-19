import XCTest
@testable import Oriel

final class StoreBridgeI18nTests: XCTestCase {
    func testCatalogExposesCoreAPI() {
        let src = StoreBridgeI18n.catalogSource
        XCTAssertTrue(src.contains("__orielStoreI18n"))
        XCTAssertTrue(src.contains("isChromeInstallLabel"))
        XCTAssertTrue(src.contains("isFirefoxInstallLabel"))
        XCTAssertTrue(src.contains("isPhoneIncompatText"))
        XCTAssertTrue(src.contains("isNeedFirefoxBanner"))
        XCTAssertTrue(src.contains("tipChrome"))
        XCTAssertTrue(src.contains("tipFirefox"))
    }

    func testCatalogIncludesMajorLocales() {
        let src = StoreBridgeI18n.catalogSource
        for lang in [
            "en", "nl", "de", "fr", "es", "it", "pt", "pl", "ru", "uk",
            "ja", "ko", "zh-cn", "zh-tw", "ar", "he", "hi", "tr", "vi", "id"
        ] {
            XCTAssertTrue(src.contains("\(lang):"), "missing locale \(lang)")
        }
        XCTAssertTrue(src.contains("Toevoegen aan Oriel"))
        XCTAssertTrue(src.contains("Zu Oriel hinzufügen"))
        XCTAssertTrue(src.contains("Ajouter à Oriel"))
        XCTAssertTrue(src.contains("添加至 Oriel") || src.contains("加到 Oriel"))
    }

    func testBridgesConsumeSharedI18n() {
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("__orielStoreI18n"))
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("L('add')"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("__orielStoreI18n"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("L('tipFirefox')"))
    }
}
