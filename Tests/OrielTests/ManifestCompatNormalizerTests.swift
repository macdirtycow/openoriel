import XCTest
@testable import Oriel

final class ManifestCompatNormalizerTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("oriel-manifest-compat-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testMapsBrowserActionToAction() throws {
        let url = try writeManifest([
            "manifest_version": 2,
            "name": "BA",
            "version": "1.0",
            "browser_action": ["default_title": "Hi"]
        ])
        XCTAssertTrue(try ManifestCompatNormalizer.normalize(at: url))
        let json = try load(url)
        XCTAssertNotNil(json["action"])
        XCTAssertNil(json["browser_action"])
        let action = try XCTUnwrap(json["action"] as? [String: Any])
        XCTAssertEqual(action["default_title"] as? String, "Hi")
    }

    func testMapsPageActionWhenActionMissing() throws {
        let url = try writeManifest([
            "manifest_version": 2,
            "name": "PA",
            "version": "1.0",
            "page_action": ["default_title": "Page"]
        ])
        XCTAssertTrue(try ManifestCompatNormalizer.normalize(at: url))
        let json = try load(url)
        XCTAssertNotNil(json["action"])
        XCTAssertNil(json["page_action"])
    }

    func testRemovesPersistentKeyEntirelyAndDropsDuplicateScripts() throws {
        let url = try writeManifest([
            "manifest_version": 3,
            "name": "SW",
            "version": "1.0",
            "background": [
                "service_worker": "bg.js",
                "scripts": ["bg.js"],
                "persistent": true
            ]
        ])
        XCTAssertTrue(try ManifestCompatNormalizer.normalize(at: url))
        let background = try XCTUnwrap(try load(url)["background"] as? [String: Any])
        XCTAssertEqual(background["service_worker"] as? String, "bg.js")
        XCTAssertNil(background["scripts"])
        // WebKit error: Invalid `persistent` manifest entry — key must be absent.
        XCTAssertNil(background["persistent"])
    }

    func testRemovesPersistentFalseAsWell() throws {
        let url = try writeManifest([
            "manifest_version": 2,
            "name": "BG",
            "version": "1.0",
            "background": [
                "scripts": ["bg.js"],
                "persistent": false
            ]
        ])
        XCTAssertTrue(try ManifestCompatNormalizer.normalize(at: url))
        let background = try XCTUnwrap(try load(url)["background"] as? [String: Any])
        XCTAssertNil(background["persistent"])
        XCTAssertEqual(background["scripts"] as? [String], ["bg.js"])
    }

    func testPromotesMV3ScriptsToServiceWorker() throws {
        let url = try writeManifest([
            "manifest_version": 3,
            "name": "Scripts",
            "version": "1.0",
            "background": [
                "scripts": ["worker.js"],
                "persistent": true
            ]
        ])
        XCTAssertTrue(try ManifestCompatNormalizer.normalize(at: url))
        let background = try XCTUnwrap(try load(url)["background"] as? [String: Any])
        XCTAssertEqual(background["service_worker"] as? String, "worker.js")
        XCTAssertNil(background["scripts"])
        XCTAssertNil(background["persistent"])
    }

    func testStripsSafariBSSNativeMessagingAndChromeStyle() throws {
        let url = try writeManifest([
            "manifest_version": 2,
            "name": "Cleanup",
            "version": "1.0",
            "permissions": ["storage", "nativeMessaging", "debugger", "tabs"],
            "optional_permissions": ["proxy"],
            "browser_specific_settings": [
                "safari": ["strict_min_version": "15.0"],
                "gecko": ["id": "cleanup@example.com"]
            ],
            "applications": ["gecko": ["id": "legacy@example.com"]],
            "options_ui": ["page": "options.html", "chrome_style": true]
        ])
        XCTAssertTrue(try ManifestCompatNormalizer.normalize(at: url))
        let json = try load(url)
        XCTAssertEqual(json["permissions"] as? [String], ["storage", "tabs"])
        XCTAssertEqual(json["optional_permissions"] as? [String], [])
        let bss = try XCTUnwrap(json["browser_specific_settings"] as? [String: Any])
        XCTAssertNil(bss["safari"])
        XCTAssertNotNil(bss["gecko"])
        XCTAssertNil(json["applications"])
        let options = try XCTUnwrap(json["options_ui"] as? [String: Any])
        XCTAssertNil(options["chrome_style"])
        XCTAssertEqual(options["page"] as? String, "options.html")
    }

    func testNormalizePackageFindsNestedManifest() throws {
        let resources = tempRoot.appendingPathComponent("Contents/Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)
        let manifestURL = resources.appendingPathComponent("manifest.json")
        let data = try JSONSerialization.data(withJSONObject: [
            "manifest_version": 2,
            "name": "Nested",
            "version": "1.0",
            "browser_action": ["default_title": "N"]
        ] as [String: Any], options: [.prettyPrinted])
        try data.write(to: manifestURL)

        ManifestCompatNormalizer.normalizePackage(at: tempRoot)
        let json = try load(manifestURL)
        XCTAssertNotNil(json["action"])
        XCTAssertNil(json["browser_action"])
    }

    // MARK: - Helpers

    private func writeManifest(_ root: [String: Any]) throws -> URL {
        let url = tempRoot.appendingPathComponent("manifest.json")
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted])
        try data.write(to: url)
        return url
    }

    private func load(_ url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
