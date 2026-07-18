import XCTest
@testable import Oriel

final class URLParserTests: XCTestCase {
    func testHTTPSURLPassthrough() {
        let result = URLParser.classify("https://example.com/path")
        guard case .url(let url) = result else {
            return XCTFail("Expected URL")
        }
        XCTAssertEqual(url.host, "example.com")
        XCTAssertEqual(url.scheme, "https")
    }

    func testBareDomainBecomesHTTPS() {
        let url = URLParser.resolve("example.com", searchEngine: .duckDuckGo)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "example.com")
    }

    func testSpacesBecomeSearch() {
        let result = URLParser.classify("swift concurrency")
        guard case .search(let query) = result else {
            return XCTFail("Expected search")
        }
        XCTAssertEqual(query, "swift concurrency")
    }

    func testSingleWordWithoutDotIsSearch() {
        let result = URLParser.classify("weather")
        guard case .search = result else {
            return XCTFail("Expected search")
        }
    }

    func testRejectedJavaScriptScheme() {
        XCTAssertFalse(URLParser.isAllowedNavigation(URL(string: "javascript:alert(1)")!))
    }

    func testSearchEngineBuildsQuery() {
        let url = SearchEngine.duckDuckGo.searchURL(for: "oriel browser")
        XCTAssertEqual(url.host, "duckduckgo.com")
        XCTAssertTrue(url.query?.contains("oriel") == true)
    }

    func testStartPageDetection() {
        XCTAssertTrue(URLParser.isStartPage(URLParser.startPageURL))
        XCTAssertFalse(URLParser.isStartPage(URL(string: "https://example.com")))
    }

    func testIPv6BareLiteralBecomesHTTPS() {
        let url = URLParser.resolve("2001:db8::1", searchEngine: .duckDuckGo)
        XCTAssertEqual(url.scheme, "https")
        XCTAssertEqual(url.host, "2001:db8::1")
    }

    func testIPv6BracketedLiteral() {
        let result = URLParser.classify("[2001:db8::1]")
        guard case .url(let url) = result else {
            return XCTFail("Expected URL for bracketed IPv6")
        }
        XCTAssertEqual(url.host, "2001:db8::1")
    }

    func testIPv6WithPortInURL() {
        let result = URLParser.classify("https://[2001:db8::1]:8443/")
        guard case .url(let url) = result else {
            return XCTFail("Expected URL")
        }
        XCTAssertEqual(url.host, "2001:db8::1")
        XCTAssertEqual(url.port, 8443)
    }
}
