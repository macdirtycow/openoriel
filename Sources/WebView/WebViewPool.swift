import Foundation
import WebKit

/// Strongly retains `WKWebView` instances per tab so switching away from a tab
/// does not deallocate the view and wipe back/forward history.
@MainActor
final class WebViewPool {
    static let shared = WebViewPool()

    private struct Entry {
        var webView: WKWebView
        /// Must match configuration-sensitive keys (profile, fingerprinting, autoplay).
        var configKey: String
        var lastAccess: Date
    }

    private var entries: [UUID: Entry] = [:]
    /// Soft cap on live web views to limit memory; protected IDs are never evicted.
    /// Pulse edition can lower this via Settings → Appearance → Pulse performance.
    var softLimit = 12 {
        didSet {
            let clamped = min(24, max(4, softLimit))
            if clamped != softLimit {
                softLimit = clamped
                return
            }
            trim(protecting: [])
        }
    }

    func existing(for tabID: UUID, configKey: String) -> WKWebView? {
        guard var entry = entries[tabID] else { return nil }
        guard entry.configKey == configKey else {
            // Configuration changed — drop the stale view.
            release(tabID)
            return nil
        }
        entry.lastAccess = .now
        entries[tabID] = entry
        return entry.webView
    }

    func store(
        _ webView: WKWebView,
        for tabID: UUID,
        configKey: String,
        protecting protected: Set<UUID> = []
    ) {
        entries[tabID] = Entry(webView: webView, configKey: configKey, lastAccess: .now)
        trim(protecting: protected.union([tabID]))
    }

    func touch(_ tabID: UUID) {
        guard var entry = entries[tabID] else { return }
        entry.lastAccess = .now
        entries[tabID] = entry
    }

    func release(_ tabID: UUID) {
        guard let entry = entries.removeValue(forKey: tabID) else { return }
        teardown(entry.webView)
    }

    func releaseAll(where shouldRelease: (UUID) -> Bool) {
        let ids = entries.keys.filter(shouldRelease)
        for id in ids {
            release(id)
        }
    }

    func releaseAll() {
        let ids = Array(entries.keys)
        for id in ids {
            release(id)
        }
    }

    private func trim(protecting protected: Set<UUID>) {
        guard entries.count > softLimit else { return }
        let victims = entries
            .filter { !protected.contains($0.key) }
            .sorted { $0.value.lastAccess < $1.value.lastAccess }
        let overflow = entries.count - softLimit
        for (id, _) in victims.prefix(overflow) {
            release(id)
        }
    }

    private func teardown(_ webView: WKWebView) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
#if os(iOS)
        webView.scrollView.delegate = nil
#endif
    }
}
