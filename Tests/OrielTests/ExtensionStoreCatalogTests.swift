import XCTest
@testable import Oriel

final class ExtensionStoreCatalogTests: XCTestCase {
    func testParseAMOSearchResults() throws {
        let json = """
        {
          "count": 1,
          "results": [
            {
              "slug": "ublock-origin",
              "name": { "en-US": "uBlock Origin" },
              "summary": { "en-US": "Finally, an efficient blocker." },
              "type": "extension",
              "icon_url": "https://addons.mozilla.org/user-media/addon_icons/607/607454-64.png",
              "ratings": { "average": 4.5 }
            }
          ]
        }
        """.data(using: .utf8)!
        let items = ExtensionStoreCatalog.parseAMOSearch(data: json, kind: .extension)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].source, .firefox)
        XCTAssertEqual(items[0].storeIdentifier, "ublock-origin")
        XCTAssertEqual(items[0].name, "uBlock Origin")
        XCTAssertEqual(items[0].kind, .extension)
        XCTAssertEqual(items[0].rating, 4.5)
    }

    func testParseAMOSearchAcceptsNSNumberRatings() throws {
        let json: [String: Any] = [
            "results": [
                [
                    "slug": "dark-theme",
                    "name": ["en-US": "Dark"],
                    "summary": ["en-US": "A dark theme"],
                    "type": "statictheme",
                    "ratings": ["average": NSNumber(value: 4.2)]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let items = ExtensionStoreCatalog.parseAMOSearch(data: data, kind: .theme)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].rating, 4.2)
        XCTAssertEqual(items[0].kind, .theme)
    }

    func testParseChromeStoreHTMLCards() {
        let html = """
        <div class="Cb7Kte" data-item-id="cjpalhdlnbpafiamejdnhcphjbkeiagm">
          <a href="/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm">x</a>
          <div>uBlock Origin</div>
          <p>Finally, an efficient blocker. Easy on CPU and memory.</p>
        </div>
        <div class="Cb7Kte" data-item-id="ddkjiahejlhfcafbddmgiahcphecmpfh">
          <a href="/detail/ublock-origin-lite/ddkjiahejlhfcafbddmgiahcphecmpfh">x</a>
          <div>uBlock Origin Lite</div>
          <span>Featured</span>
        </div>
        """
        let items = ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].source, .chrome)
        XCTAssertEqual(items[0].storeIdentifier, "cjpalhdlnbpafiamejdnhcphjbkeiagm")
        XCTAssertEqual(items[0].name, "uBlock Origin")
        XCTAssertTrue(items[0].storeURL?.absoluteString.contains("ublock-origin") == true)
        XCTAssertEqual(items[1].name, "uBlock Origin Lite")
    }

    func testParseChromeStoreHTMLFallsBackToDetailLinks() {
        let html = """
        <a href="/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh">Dark Reader</a>
        <a href="/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm">uBlock</a>
        """
        let items = ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].storeIdentifier, "eimadpbcbfnmbkopoojfekhnkhdbieeh")
        XCTAssertEqual(items[0].name, "Dark Reader")
        XCTAssertEqual(items[1].storeIdentifier, "cjpalhdlnbpafiamejdnhcphjbkeiagm")
    }

    func testInvalidChromeIDsIgnored() {
        let html = #"<div data-item-id="not-a-valid-id-here-at-all!!!!">Nope</div>"#
        XCTAssertTrue(ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension).isEmpty)
    }

    func testRawStringQuoteBugRegression() {
        // Ensures we match real HTML quotes, not the Swift raw-string \" pitfall.
        let html = "<div data-item-id=\"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\">Title Here</div>"
        let items = ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].storeIdentifier, "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    }

    func testParseChromeEmbeddedPayload() {
        let html = """
        AF_initDataCallback({key: 'ds:1', data:[[[[["cjpalhdlnbpafiamejdnhcphjbkeiagm","https://lh3.googleusercontent.com/icon","uBlock Origin",4.8,99,"https://lh3.googleusercontent.com/banner","Finally, an efficient blocker."]]]]], sideChannel: {}});
        """
        let items = ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].storeIdentifier, "cjpalhdlnbpafiamejdnhcphjbkeiagm")
        XCTAssertEqual(items[0].name, "uBlock Origin")
        XCTAssertEqual(items[0].rating, 4.8)
        XCTAssertEqual(items[0].iconURL?.host, "lh3.googleusercontent.com")
        XCTAssertTrue(items[0].summary.contains("efficient"))
    }

    func testParseChromeRelativeDetailLinks() {
        let html = #"<a href="./detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh">x</a>"#
        let items = ExtensionStoreCatalog.parseChromeStoreHTML(html, kind: .extension)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].storeIdentifier, "eimadpbcbfnmbkopoojfekhnkhdbieeh")
        XCTAssertEqual(items[0].name, "Dark Reader")
    }

    func testCuratedFallbackNeverEmptyForPopular() {
        XCTAssertFalse(ExtensionStoreCatalog.curatedFallback(source: .chrome, kind: .extension, query: "").isEmpty)
        XCTAssertFalse(ExtensionStoreCatalog.curatedFallback(source: .chrome, kind: .theme, query: "").isEmpty)
        XCTAssertFalse(ExtensionStoreCatalog.curatedFallback(source: .firefox, kind: .extension, query: "").isEmpty)
        XCTAssertFalse(ExtensionStoreCatalog.curatedFallback(source: .firefox, kind: .theme, query: "").isEmpty)
        XCTAssertTrue(
            ExtensionStoreCatalog.curatedFallback(source: .chrome, kind: .extension, query: "ublock")
                .contains(where: { $0.storeIdentifier == "cjpalhdlnbpafiamejdnhcphjbkeiagm" })
        )
    }

    func testChromeCatalogURLsIncludeLocaleHints() {
        let urls = ExtensionStoreCatalog.chromeCatalogURLs(query: "", kind: .extension)
        XCTAssertTrue(urls.contains(where: { $0.absoluteString.contains("hl=en") }))
        XCTAssertTrue(urls.contains(where: { $0.absoluteString.contains("/category/extensions") }))
        let search = ExtensionStoreCatalog.chromeCatalogURLs(query: "vpn", kind: .theme)
        XCTAssertEqual(search.count, 1)
        XCTAssertTrue(search[0].absoluteString.contains("itemTypes=2"))
        let privacy = StoreBrowseCategory.categories(for: .extension).first(where: { $0.id == "privacy-security" })
        let privacyURLs = ExtensionStoreCatalog.chromeCatalogURLs(query: "", kind: .extension, category: privacy)
        XCTAssertTrue(privacyURLs.contains(where: { $0.absoluteString.contains("privacy") }))
    }

    func testNormalizationKeyMergesStoreVariants() {
        XCTAssertEqual(
            ExtensionStoreCatalog.normalizationKey(forName: "Dark Reader"),
            ExtensionStoreCatalog.normalizationKey(forName: "Dark Reader for Firefox")
        )
        XCTAssertEqual(
            ExtensionStoreCatalog.normalizationKey(forName: "uBlock Origin"),
            "ublockorigin"
        )
        let bitwarden = ExtensionStoreCatalog.normalizationKey(forName: "Bitwarden")
        let bitwardenLong = ExtensionStoreCatalog.normalizationKey(forName: "Bitwarden Password Manager")
        XCTAssertTrue(bitwardenLong.hasPrefix(bitwarden))
    }

    func testMergeIntoUniversalCombinesSources() {
        let items: [ExtensionStoreItem] = [
            ExtensionStoreItem(
                source: .chrome,
                kind: .extension,
                storeIdentifier: "eimadpbcbfnmbkopoojfekhnkhdbieeh",
                name: "Dark Reader",
                summary: "Dark mode",
                iconURL: nil,
                rating: 4.7,
                storeURL: nil
            ),
            ExtensionStoreItem(
                source: .firefox,
                kind: .extension,
                storeIdentifier: "darkreader",
                name: "Dark Reader for Firefox",
                summary: "Dark mode for every website",
                iconURL: nil,
                rating: 4.8,
                storeURL: nil
            ),
            ExtensionStoreItem(
                source: .safari,
                kind: .extension,
                storeIdentifier: "known:darkreader",
                name: "Dark Reader",
                summary: "Safari Web Extension",
                iconURL: nil,
                rating: nil,
                storeURL: nil
            )
        ]
        let listings = ExtensionStoreCatalog.mergeIntoUniversal(items, kind: .extension, limit: 10)
        XCTAssertEqual(listings.count, 1)
        XCTAssertEqual(listings[0].name, "Dark Reader")
        XCTAssertEqual(Set(listings[0].availableSources), Set([.chrome, .firefox, .safari]))
        // Firefox preferred for Add when not installed.
        XCTAssertEqual(listings[0].preferredOffer?.source, .firefox)
        XCTAssertEqual(ExtensionStoreItem.Source.chrome.installedFromLabel, "Installed from Chrome Web Store")
        XCTAssertEqual(ExtensionStoreItem.Source.firefox.installedFromLabel, "Installed from Firefox Add-ons")
    }

    func testKnownMultiStoreSeedsIncludeDarkReader() {
        let seeds = ExtensionStoreCatalog.knownMultiStoreSeeds(kind: .extension, query: "dark reader")
        let sources = Set(seeds.map(\.source))
        XCTAssertTrue(sources.contains(.chrome))
        XCTAssertTrue(sources.contains(.firefox))
        XCTAssertTrue(sources.contains(.safari))
    }

    func testBrowseCategoriesCoverExtensionsAndThemes() {
        let extensions = StoreBrowseCategory.categories(for: .extension)
        let themes = StoreBrowseCategory.categories(for: .theme)
        XCTAssertGreaterThanOrEqual(extensions.count, 10)
        XCTAssertGreaterThanOrEqual(themes.count, 8)
        XCTAssertEqual(extensions.first?.id, StoreBrowseCategory.featuredExtensions.id)
        XCTAssertTrue(extensions.contains(where: { $0.firefoxCategory == "privacy-security" }))
        XCTAssertTrue(themes.contains(where: { $0.firefoxCategory == "nature" }))
    }

    func testSortOptionsDependOnQuery() {
        XCTAssertEqual(StoreBrowseSort.options(forQuery: ""), [.popular, .rating, .recent])
        XCTAssertTrue(StoreBrowseSort.options(forQuery: "dark").contains(.relevance))
        XCTAssertEqual(StoreBrowseSort.popular.firefoxSort, "users")
        XCTAssertEqual(StoreBrowseSort.recent.firefoxSort, "created")
    }

    func testParseAMODetailIncludesDescriptionAndScreenshots() throws {
        let json: [String: Any] = [
            "slug": "darkreader",
            "name": ["en-US": "Dark Reader"],
            "summary": ["en-US": "Dark mode for every website."],
            "description": ["en-US": "<p>This eye-care extension enables night mode.</p><p>Adjust brightness.</p>"],
            "icon_url": "https://addons.mozilla.org/icon.png",
            "average_daily_users": 1_000_000,
            "ratings": ["average": 4.5],
            "authors": [["name": "Dark Reader Ltd"]],
            "previews": [
                ["image_url": "https://addons.mozilla.org/preview1.png"],
                ["thumbnail_url": "https://addons.mozilla.org/thumb2.jpg"]
            ],
            "current_version": [
                "version": "4.9.0",
                "file": ["permissions": ["storage", "tabs"]]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: json)
        let listing = UnifiedStoreListing(
            id: "darkreader",
            kind: .extension,
            name: "Dark Reader",
            summary: "fallback",
            iconURL: nil,
            rating: nil,
            offers: [
                ExtensionStoreItem(
                    source: .firefox,
                    kind: .extension,
                    storeIdentifier: "darkreader",
                    name: "Dark Reader",
                    summary: "fallback",
                    iconURL: nil,
                    rating: nil,
                    storeURL: nil
                )
            ]
        )
        let detail = try XCTUnwrap(ExtensionStoreCatalog.parseAMODetail(data: data, listing: listing))
        XCTAssertEqual(detail.name, "Dark Reader")
        XCTAssertTrue(detail.description.contains("eye-care"))
        XCTAssertEqual(detail.screenshotURLs.count, 2)
        XCTAssertEqual(detail.userCount, 1_000_000)
        XCTAssertEqual(detail.authorName, "Dark Reader Ltd")
        XCTAssertEqual(detail.version, "4.9.0")
        XCTAssertEqual(detail.permissions, ["storage", "tabs"])
        XCTAssertEqual(detail.primarySource, .firefox)
    }

    func testParseChromeDetailHTMLExtractsDescriptionAndScreenshots() {
        let html = """
        <meta property="og:title" content="Dark Reader - Chrome Web Store">
        <meta property="og:description" content="Dark mode for every website.">
        <p>Short nav</p>
        <p>This eye-care extension enables night mode by creating dark themes for websites on the fly. Dark Reader inverts bright colors.</p>
        <p>Adjust brightness, contrast, the sepia filter, and font preferences for comfortable reading.</p>
        <img src="https://lh3.googleusercontent.com/abc123XYZ=s550-w550-h350">
        <img src="https://lh3.googleusercontent.com/def456UVW=s550-w550-h350">
        <img src="https://lh3.googleusercontent.com/abc123XYZ=s128-rj">
        """
        let listing = UnifiedStoreListing(
            id: "darkreader",
            kind: .extension,
            name: "Dark Reader",
            summary: "fallback",
            iconURL: nil,
            rating: 4.4,
            offers: [
                ExtensionStoreItem(
                    source: .chrome,
                    kind: .extension,
                    storeIdentifier: "eimadpbcbfnmbkopoojfekhnkhdbieeh",
                    name: "Dark Reader",
                    summary: "fallback",
                    iconURL: nil,
                    rating: 4.4,
                    storeURL: nil
                )
            ]
        )
        let detail = ExtensionStoreCatalog.parseChromeDetailHTML(
            html,
            storeID: "eimadpbcbfnmbkopoojfekhnkhdbieeh",
            listing: listing
        )
        XCTAssertNotNil(detail)
        XCTAssertEqual(detail?.name, "Dark Reader")
        XCTAssertTrue(detail?.description.contains("eye-care") == true)
        XCTAssertEqual(detail?.screenshotURLs.count, 2)
        XCTAssertEqual(detail?.primarySource, .chrome)
    }

    func testStripHTMLRemovesTags() {
        let plain = ExtensionStoreCatalog.stripHTML("<p>Hello <b>world</b></p><br/>Next")
        XCTAssertTrue(plain.contains("Hello world"))
        XCTAssertTrue(plain.contains("Next"))
        XCTAssertFalse(plain.contains("<"))
    }
}
