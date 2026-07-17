import XCTest
@testable import Oriel

final class Phase2StoreTests: XCTestCase {
    func testBookmarkAddAndSearch() async {
        await MainActor.run {
            let store = BookmarkStore()
            let before = store.bookmarks.count
            store.add(title: "Example", url: URL(string: "https://example.com")!)
            XCTAssertGreaterThanOrEqual(store.bookmarks.count, before)
            XCTAssertFalse(store.search("example").isEmpty)
        }
    }

    func testHistorySkipsStartPage() async {
        await MainActor.run {
            let store = HistoryStore()
            let before = store.entries.count
            store.record(title: "Home", url: URLParser.startPageURL)
            XCTAssertEqual(store.entries.count, before)
            store.record(title: "Example", url: URL(string: "https://example.com/page")!)
            XCTAssertGreaterThan(store.entries.count, before)
        }
    }

    func testTabLifecycle() async {
        await MainActor.run {
            let manager = TabManager(searchEngine: .duckDuckGo, restoring: nil)
            XCTAssertEqual(manager.tabs.count, 1)
            let second = manager.createTab(url: URL(string: "https://example.com"), select: true)
            XCTAssertEqual(manager.tabs.count, 2)
            XCTAssertEqual(manager.activeTabID, second.id)
            manager.closeTab(id: second.id)
            XCTAssertEqual(manager.tabs.count, 1)
            XCTAssertTrue(manager.canRestoreClosedTab)
            _ = manager.restoreClosedTab()
            XCTAssertEqual(manager.tabs.count, 2)
        }
    }
}
