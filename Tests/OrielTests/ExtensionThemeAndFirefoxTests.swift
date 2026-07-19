import XCTest
@testable import Oriel

final class ExtensionThemeAndFirefoxTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("oriel-theme-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testParseChromeThemeRGBArrays() throws {
        let root = try makeThemePackage(
            colors: [
                "frame": [40, 60, 90],
                "toolbar": [20, 100, 160],
                "ntp_background": [245, 248, 252]
            ],
            images: ["theme_ntp_background": "ntp.png"]
        )
        let parsed = try ExtensionThemeParser.parse(packageRoot: root, source: .chrome)
        XCTAssertEqual(parsed.source, .chrome)
        XCTAssertEqual(parsed.accentRGB[0], 20.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(parsed.backgroundRGB[0], 245.0 / 255.0, accuracy: 0.001)
        XCTAssertEqual(parsed.ntpImageRelativePath, "ntp.png")
        XCTAssertFalse(parsed.prefersDark)
        XCTAssertTrue(ExtensionThemeParser.isThemeOnlyPackage(at: root))
    }

    func testParseFirefoxCSSColors() throws {
        let root = try makeThemePackage(
            colors: [
                "frame": "#1a1a2e",
                "toolbar": "rgb(30, 40, 80)",
                "ntp_background": "#0f0f1a"
            ],
            images: [:]
        )
        let parsed = try ExtensionThemeParser.parse(packageRoot: root, source: .firefox)
        XCTAssertTrue(parsed.prefersDark)
        XCTAssertEqual(parsed.backgroundRGB[0], 15.0 / 255.0, accuracy: 0.01)
        XCTAssertEqual(parsed.source, .firefox)
    }

    func testHybridPackageIsNotThemeOnly() throws {
        let root = try makeThemePackage(
            colors: ["toolbar": [10, 20, 30]],
            images: [:],
            extra: ["background": ["scripts": ["bg.js"], "persistent": false]]
        )
        XCTAssertTrue(ExtensionThemeParser.manifestContainsTheme(at: root))
        XCTAssertFalse(ExtensionThemeParser.isThemeOnlyPackage(at: root))
    }

    func testFirefoxSlugFromStoreURL() {
        let url = URL(string: "https://addons.mozilla.org/en-US/firefox/addon/ublock-origin/")!
        XCTAssertEqual(FirefoxAddonsAPI.slug(fromStoreURL: url), "ublock-origin")
        let install = FirefoxAddonsAPI.installURL(forSlug: "dark-theme")!
        XCTAssertEqual(FirefoxAddonsAPI.slug(fromInstallURL: install), "dark-theme")
        XCTAssertTrue(FirefoxAddonsBridge.desktopSpoofSource.contains("InstallTrigger"))
        XCTAssertTrue(FirefoxAddonsBridge.desktopSpoofSource.contains("MacIntel"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("need firefox"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("oriel-amo-tip"))
        XCTAssertTrue(FirefoxAddonsBridge.userScriptSource.contains("oriel-add-firefox-to-oriel"))
    }

    func testFirefoxXPIURLFromDetailJSON() throws {
        let json: [String: Any] = [
            "name": ["en-US": "Sample"],
            "current_version": [
                "file": [
                    "url": "https://addons.mozilla.org/firefox/downloads/file/1/sample.xpi"
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let url = FirefoxAddonsAPI.xpiURL(fromDetailJSON: data)
        XCTAssertEqual(url?.pathExtension, "xpi")
        XCTAssertEqual(FirefoxAddonsAPI.displayName(fromDetailJSON: data), "Sample")
    }

    func testSettingsApplyAndClearExtensionTheme() async {
        await MainActor.run {
            let defaults = UserDefaults(suiteName: "oriel.tests.exttheme.\(UUID().uuidString)")!
            let settings = BrowserSettings(defaults: defaults)
            settings.applyExtensionTheme(
                id: "demo",
                accentRGB: [0.1, 0.2, 0.3],
                backgroundRGB: [0.9, 0.9, 0.9],
                prefersDark: false
            )
            XCTAssertTrue(settings.usesExtensionTheme)
            XCTAssertEqual(settings.activeExtensionThemeID, "demo")
            XCTAssertEqual(settings.appearance, .light)

            let reloaded = BrowserSettings(defaults: defaults)
            XCTAssertEqual(reloaded.activeExtensionThemeID, "demo")
            XCTAssertEqual(reloaded.customAccentRGB?[0] ?? 0, 0.1, accuracy: 0.0001)

            reloaded.clearExtensionTheme()
            XCTAssertFalse(reloaded.usesExtensionTheme)
            XCTAssertNil(reloaded.activeExtensionThemeID)
        }
    }

    // MARK: - Fixtures

    private func makeThemePackage(
        colors: [String: Any],
        images: [String: Any],
        extra: [String: Any] = [:]
    ) throws -> URL {
        let root = tempRoot.appendingPathComponent("pkg-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var manifest: [String: Any] = [
            "manifest_version": 2,
            "name": "Sample Theme",
            "version": "1.0.0",
            "theme": [
                "colors": colors,
                "images": images
            ]
        ]
        for (key, value) in extra {
            manifest[key] = value
        }
        let data = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
        try data.write(to: root.appendingPathComponent("manifest.json"))
        if images["theme_ntp_background"] != nil {
            try Data([0x89, 0x50, 0x4E, 0x47]).write(to: root.appendingPathComponent("ntp.png"))
        }
        return root
    }
}
