import XCTest
@testable import Oriel

final class SafariWebExtensionImporterTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("oriel-safari-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testClassifySafariWebExtension() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.webExtensionPoint,
            includeManifest: true
        )
        let candidate = SafariWebExtensionImporter.classify(appexURL: appex)
        XCTAssertEqual(candidate.kind, .safariWebExtension)
        XCTAssertTrue(candidate.isImportable)
        XCTAssertNotNil(candidate.manifestURL)
        XCTAssertEqual(candidate.bundleIdentifier, "com.example.SafariWebExt")
    }

    func testClassifyLegacySafariAppExtension() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.legacyExtensionPoint,
            includeManifest: false
        )
        let candidate = SafariWebExtensionImporter.classify(appexURL: appex)
        XCTAssertEqual(candidate.kind, .legacySafariAppExtension)
        XCTAssertFalse(candidate.isImportable)
    }

    func testClassifyContentBlocker() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.contentBlockerPoint,
            includeManifest: false
        )
        let candidate = SafariWebExtensionImporter.classify(appexURL: appex)
        XCTAssertEqual(candidate.kind, .contentBlocker)
        XCTAssertFalse(candidate.isImportable)
    }

    func testFindManifestPrefersResources() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.webExtensionPoint,
            includeManifest: true
        )
        let found = SafariWebExtensionImporter.findManifest(in: appex)
        XCTAssertEqual(found?.lastPathComponent, "manifest.json")
        XCTAssertTrue(found?.path.contains("Resources") == true)
    }

    func testExtractCopiesWebExtensionTreeOnly() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.webExtensionPoint,
            includeManifest: true
        )
        let destination = tempRoot.appendingPathComponent("out", isDirectory: true)
        try SafariWebExtensionImporter.extractWebExtensionResources(from: appex, to: destination)

        let manifest = destination.appendingPathComponent("manifest.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: manifest.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: destination.appendingPathComponent("Info.plist").path
            )
        )
        // Safari-only browser_specific_settings.safari should be stripped.
        let data = try Data(contentsOf: manifest)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let bss = json["browser_specific_settings"] as? [String: Any]
        XCTAssertNil(bss?["safari"])
    }

    func testExtractRejectsLegacy() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.legacyExtensionPoint,
            includeManifest: false
        )
        let destination = tempRoot.appendingPathComponent("legacy-out", isDirectory: true)
        XCTAssertThrowsError(
            try SafariWebExtensionImporter.extractWebExtensionResources(from: appex, to: destination)
        ) { error in
            XCTAssertEqual(error as? SafariImportError, .legacySafariOnly)
        }
    }

    func testExtractRejectsAppexWithoutManifest() throws {
        let appex = try makeAppex(
            point: SafariWebExtensionImporter.webExtensionPoint,
            includeManifest: false
        )
        let destination = tempRoot.appendingPathComponent("empty-out", isDirectory: true)
        XCTAssertThrowsError(
            try SafariWebExtensionImporter.extractWebExtensionResources(from: appex, to: destination)
        ) { error in
            XCTAssertEqual(error as? SafariImportError, .missingManifestInAppex)
        }
    }

    // MARK: - Fixtures

    private func makeAppex(point: String, includeManifest: Bool) throws -> URL {
        let appex = tempRoot
            .appendingPathComponent("Sample.appex", isDirectory: true)
        let contents = appex.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        let info: [String: Any] = [
            "CFBundleIdentifier": "com.example.SafariWebExt",
            "CFBundleName": "Sample Safari Ext",
            "CFBundleDisplayName": "Sample Safari Ext",
            "CFBundleShortVersionString": "1.2.3",
            "NSExtension": [
                "NSExtensionPointIdentifier": point
            ]
        ]
        let infoURL = contents.appendingPathComponent("Info.plist")
        let infoData = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        try infoData.write(to: infoURL)

        // Native binary stub — must not be copied into Oriel’s staged tree.
        let macosDir = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macosDir, withIntermediateDirectories: true)
        try Data("mach-o-stub".utf8).write(to: macosDir.appendingPathComponent("Sample"), options: .atomic)

        if includeManifest {
            let manifest: [String: Any] = [
                "manifest_version": 2,
                "name": "Sample Safari Ext",
                "version": "1.2.3",
                "background": ["scripts": ["background.js"], "persistent": false],
                "browser_specific_settings": [
                    "safari": ["strict_min_version": "15.0"]
                ]
            ]
            let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted])
            try manifestData.write(to: resources.appendingPathComponent("manifest.json"))
            try Data("// bg".utf8).write(to: resources.appendingPathComponent("background.js"))
        }

        return appex
    }
}
