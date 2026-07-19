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
            "ja", "ko", "zh-cn", "zh-tw", "ar", "he", "hi", "tr", "vi", "id",
            "fil", "sw", "sr", "cy", "is", "ga", "eu", "bn", "ta", "ne"
        ] {
            XCTAssertTrue(src.contains("\(lang):"), "missing locale \(lang)")
        }
        XCTAssertTrue(src.contains("Toevoegen aan Oriel"))
        XCTAssertTrue(src.contains("Zu Oriel hinzufügen"))
        XCTAssertTrue(src.contains("Ajouter à Oriel"))
        XCTAssertTrue(src.contains("添加至 Oriel") || src.contains("加到 Oriel"))
        XCTAssertTrue(src.contains("Geïnstalleerd in Oriel") || src.contains("installed:"))
        XCTAssertTrue(src.contains("Verwijderen uit Oriel"))
        XCTAssertTrue(src.contains("Remove from Oriel"))
        XCTAssertTrue(src.contains("Aus Oriel entfernen"))
        XCTAssertTrue(src.contains("isChromeRemoveLabel"))
    }

    func testBridgesConsumeSharedI18n() {
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("__orielStoreI18n"))
        XCTAssertTrue(ChromeWebStoreBridge.userScriptSource.contains("L('add')"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("__orielStoreI18n"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("L('tipFirefox')"))
    }
}
