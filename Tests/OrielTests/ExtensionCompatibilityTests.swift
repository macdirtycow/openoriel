import XCTest
@testable import Oriel

final class ExtensionCompatibilityTests: XCTestCase {
    func testDarkReaderIsFullySupported() {
        let listing = UnifiedStoreListing(
            id: "darkreader",
            kind: .extension,
            name: "Dark Reader",
            summary: "Dark mode",
            iconURL: nil,
            rating: 4.8,
            offers: [
                ExtensionStoreItem(
                    source: .firefox,
                    kind: .extension,
                    storeIdentifier: "darkreader",
                    name: "Dark Reader",
                    summary: "",
                    iconURL: nil,
                    rating: 4.8,
                    storeURL: nil
                )
            ]
        )
        let report = ExtensionCompatibility.assess(listing)
        XCTAssertEqual(report.level, .full)
        XCTAssertFalse(report.shouldWarnBeforeInstall)
        XCTAssertGreaterThanOrEqual(report.score.percent, 90)
        XCTAssertNotNil(report.score.worksAsExpectedPercent)
    }

    func testUBlockOriginIsPartialWithWarning() {
        let listing = UnifiedStoreListing(
            id: "ublockorigin",
            kind: .extension,
            name: "uBlock Origin",
            summary: "Blocker",
            iconURL: nil,
            rating: 4.9,
            offers: [
                ExtensionStoreItem(
                    source: .firefox,
                    kind: .extension,
                    storeIdentifier: "ublock-origin",
                    name: "uBlock Origin",
                    summary: "",
                    iconURL: nil,
                    rating: 4.9,
                    storeURL: nil,
                    permissions: ["privacy", "dns", "webRequestBlocking", "storage"]
                )
            ]
        )
        let report = ExtensionCompatibility.assess(listing)
        XCTAssertEqual(report.level, .partial)
        XCTAssertTrue(report.shouldWarnBeforeInstall)
        XCTAssertTrue(report.installWarning.contains("unavailable on WebKit"))
    }

    func testUnknownPermissionsDoNotBlockAddBehindDialog() {
        let listing = UnifiedStoreListing(
            id: "somechromeonly",
            kind: .extension,
            name: "Some Chrome Only",
            summary: "",
            iconURL: nil,
            rating: nil,
            offers: [
                ExtensionStoreItem(
                    source: .chrome,
                    kind: .extension,
                    storeIdentifier: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
                    name: "Some Chrome Only",
                    summary: "",
                    iconURL: nil,
                    rating: nil,
                    storeURL: nil,
                    permissions: []
                )
            ]
        )
        let report = ExtensionCompatibility.assess(listing)
        // May be partial/estimated, but Add must not require a confirmation with no API evidence.
        XCTAssertFalse(report.shouldWarnBeforeInstall)
    }

    func testDebuggerPermissionMarksUnsupported() {
        let listing = UnifiedStoreListing(
            id: "somedebuggertool",
            kind: .extension,
            name: "Debugger Tool",
            summary: "",
            iconURL: nil,
            rating: nil,
            offers: [
                ExtensionStoreItem(
                    source: .firefox,
                    kind: .extension,
                    storeIdentifier: "debugger-tool",
                    name: "Debugger Tool",
                    summary: "",
                    iconURL: nil,
                    rating: nil,
                    storeURL: nil,
                    permissions: ["debugger", "tabs"]
                )
            ]
        )
        let report = ExtensionCompatibility.assess(listing)
        XCTAssertEqual(report.level, .unsupported)
        XCTAssertTrue(report.shouldWarnBeforeInstall)
    }

    func testThemesAreFullySupported() {
        let listing = UnifiedStoreListing(
            id: "deepdark",
            kind: .theme,
            name: "Deep Dark",
            summary: "",
            iconURL: nil,
            rating: nil,
            offers: [
                ExtensionStoreItem(
                    source: .chrome,
                    kind: .theme,
                    storeIdentifier: "eeffcpnmcmfdfnaadpnkldhkcjjiihcf",
                    name: "Deep Dark",
                    summary: "",
                    iconURL: nil,
                    rating: nil,
                    storeURL: nil
                )
            ]
        )
        XCTAssertEqual(ExtensionCompatibility.assess(listing).level, .full)
    }

    func testLocalInstallCounterIncrements() {
        let id = "testlocalinstall\(UUID().uuidString)"
        XCTAssertEqual(ExtensionCompatibility.localInstallCount(listingID: id), 0)
        ExtensionCompatibility.recordLocalInstall(listingID: id)
        ExtensionCompatibility.recordLocalInstall(listingID: id)
        XCTAssertEqual(ExtensionCompatibility.localInstallCount(listingID: id), 2)
    }

    func testAMOPermissionsParsedForCompat() throws {
        let json = """
        {
          "results": [
            {
              "slug": "proxy-switch",
              "name": { "en-US": "Proxy Switch" },
              "summary": { "en-US": "Needs proxy API" },
              "type": "extension",
              "current_version": {
                "file": {
                  "permissions": ["proxy", "storage", "tabs"]
                }
              }
            }
          ]
        }
        """.data(using: .utf8)!
        let items = ExtensionStoreCatalog.parseAMOSearch(data: json, kind: .extension)
        XCTAssertEqual(items[0].permissions, ["proxy", "storage", "tabs"])
        let listing = ExtensionStoreCatalog.mergeIntoUniversal(items, kind: .extension, limit: 5)[0]
        let report = ExtensionCompatibility.assess(listing)
        XCTAssertEqual(report.level, .unsupported)
    }
}
