import XCTest
@testable import Oriel

final class Phase7BrowserParityTests: XCTestCase {
    func testBookmarkHTMLImporter() {
        let html = """
        <!DOCTYPE NETSCAPE-Bookmark-file-1>
        <DL><p>
        <DT><A HREF="https://openoriel.com/">Oriel</A>
        <DT><A HREF="https://example.com/path">Example</A>
        <DT><A HREF="javascript:void(0)">Skip</A>
        </DL>
        """
        let items = BookmarkHTMLImporter.parse(html)
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].url.host, "openoriel.com")
        XCTAssertEqual(items[1].title, "Example")
    }

    func testFaviconResolver() {
        let url = URL(string: "https://www.example.com/page")!
        let icon = FaviconResolver.iconURL(for: url)
        XCTAssertEqual(icon?.host, "icons.duckduckgo.com")
        XCTAssertTrue(icon?.absoluteString.contains("example.com") == true)
    }

    @MainActor
    func testPinTabReorders() {
        let manager = TabManager(searchEngine: .duckDuckGo, restoring: nil)
        let second = manager.createTab(url: URL(string: "https://example.com"), select: false)
        manager.togglePin(id: second.id)
        XCTAssertTrue(manager.tabs.first?.id == second.id)
        XCTAssertTrue(manager.tabs.first?.isPinned == true)
    }
}
