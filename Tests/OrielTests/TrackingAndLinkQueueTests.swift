import XCTest
@testable import Oriel

final class TrackingAndLinkQueueTests: XCTestCase {
    func testStripsUTMAndClickIDs() {
        let url = URL(string: "https://example.com/article?id=42&utm_source=twitter&utm_medium=social&fbclid=abc&keep=yes")!
        let result = TrackingParameterStripper.strip(url, enabled: true)
        XCTAssertTrue(result.didStrip)
        let items = URLComponents(url: result.url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let names = Set(items.map(\.name))
        XCTAssertEqual(names, ["id", "keep"])
        XCTAssertFalse(result.url.absoluteString.contains("utm_"))
        XCTAssertFalse(result.url.absoluteString.contains("fbclid"))
    }

    func testStripDisabledLeavesURLAlone() {
        let url = URL(string: "https://example.com/?utm_source=x&gclid=1")!
        let result = TrackingParameterStripper.strip(url, enabled: false)
        XCTAssertFalse(result.didStrip)
        XCTAssertEqual(result.url, url)
    }

    func testStripNoOpWhenClean() {
        let url = URL(string: "https://example.com/path?q=hello")!
        let result = TrackingParameterStripper.strip(url, enabled: true)
        XCTAssertFalse(result.didStrip)
        XCTAssertEqual(result.url, url)
    }

    func testLinkQueueEnqueueDedupes() async {
        await MainActor.run {
            let store = LinkQueueStore()
            store.clear()
            let url = URL(string: "https://example.com/later")!
            store.enqueue(title: "One", url: url)
            store.enqueue(title: "Two", url: url)
            XCTAssertEqual(store.count, 1)
            XCTAssertEqual(store.items.first?.title, "One")
            store.clear()
            XCTAssertEqual(store.count, 0)
        }
    }

    func testStripTrackingSettingPersists() async {
        await MainActor.run {
            let suite = "oriel.tests.strip.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            defer { defaults.removePersistentDomain(forName: suite) }

            let first = BrowserSettings(defaults: defaults)
            XCTAssertTrue(first.stripTrackingParameters)
            first.stripTrackingParameters = false

            let second = BrowserSettings(defaults: defaults)
            XCTAssertFalse(second.stripTrackingParameters)
        }
    }
}
