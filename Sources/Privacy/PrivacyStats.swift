import Foundation
import Observation

/// Session and lifetime privacy counters.
/// Tracker hits come from NavigationPolicy + an in-page probe (WebKit has no blocker hit stream).
/// Session counters persist across app relaunches and only reset when Fire clears them.
@Observable
@MainActor
final class PrivacyStats {
    private(set) var blockedRequestsSession: Int = 0
    private(set) var httpsUpgradesSession: Int = 0
    private(set) var cookiesBlockedSession: Int = 0
    private(set) var blockedRequestsLifetime: Int = 0
    private(set) var httpsUpgradesLifetime: Int = 0
    private(set) var cookiesBlockedLifetime: Int = 0
    /// Estimated browsing time saved (milliseconds).
    private(set) var timeSavedMillisecondsSession: Int = 0
    private(set) var timeSavedMillisecondsLifetime: Int = 0

    /// ~50ms per blocked tracker/ad request (same ballpark as Brave’s estimate).
    static let millisecondsSavedPerBlock = 50

    private let fileName: String

    init(fileName: String = "privacy-stats.json") {
        self.fileName = fileName
        if let loaded = try? JSONFileStore.load(Persisted.self, from: fileName) {
            blockedRequestsSession = loaded.blockedRequestsSession ?? 0
            httpsUpgradesSession = loaded.httpsUpgradesSession ?? 0
            cookiesBlockedSession = loaded.cookiesBlockedSession ?? 0
            timeSavedMillisecondsSession = loaded.timeSavedMillisecondsSession
                ?? ((loaded.blockedRequestsSession ?? 0) * Self.millisecondsSavedPerBlock)
            blockedRequestsLifetime = loaded.blockedRequestsLifetime
            httpsUpgradesLifetime = loaded.httpsUpgradesLifetime
            cookiesBlockedLifetime = loaded.cookiesBlockedLifetime
            timeSavedMillisecondsLifetime = loaded.timeSavedMillisecondsLifetime
                ?? (loaded.blockedRequestsLifetime * Self.millisecondsSavedPerBlock)
        }
    }

    var minutesSavedSession: Double {
        Double(timeSavedMillisecondsSession) / 60_000.0
    }

    var minutesSavedLifetime: Double {
        Double(timeSavedMillisecondsLifetime) / 60_000.0
    }

    func recordBlockedRequest(count: Int = 1, url: URL? = nil, cookieRelated: Bool? = nil) {
        guard count > 0 else { return }
        blockedRequestsSession += count
        blockedRequestsLifetime += count
        let saved = count * Self.millisecondsSavedPerBlock
        timeSavedMillisecondsSession += saved
        timeSavedMillisecondsLifetime += saved

        let isCookie = cookieRelated ?? (url.map(Self.looksCookieRelated) ?? false)
        if isCookie {
            cookiesBlockedSession += count
            cookiesBlockedLifetime += count
        }
        persist()
    }

    func recordCookiesBlocked(_ count: Int = 1) {
        guard count > 0 else { return }
        cookiesBlockedSession += count
        cookiesBlockedLifetime += count
        persist()
    }

    func recordHTTPSUpgrade() {
        httpsUpgradesSession += 1
        httpsUpgradesLifetime += 1
        persist()
    }

    func resetSessionCounters() {
        blockedRequestsSession = 0
        httpsUpgradesSession = 0
        cookiesBlockedSession = 0
        timeSavedMillisecondsSession = 0
        persist()
    }

    /// Hosts / paths commonly used for cookie sync, consent pixels, and identity trackers.
    nonisolated static func looksCookieRelated(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        let haystack = host + path

        let hostHints = [
            "doubleclick", "googlesyndication", "googleadservices",
            "facebook.com", "facebook.net", "fbcdn",
            "adservice", "scorecardresearch", "quantserve",
            "hotjar", "fullstory", "mouseflow",
            "segment.io", "segment.com", "mixpanel", "amplitude",
            "criteo", "taboola", "outbrain",
            "cookiebot", "cookielaw", "onetrust", "trustarc",
            "consent", "privacymanager", "demdex", "bluekai", "krxd"
        ]
        if hostHints.contains(where: { host.contains($0) }) {
            return true
        }

        let pathHints = [
            "/cookie", "cookiebot", "onetrust", "consent",
            "/track", "/pixel", "/beacon", "collect"
        ]
        return pathHints.contains(where: { haystack.contains($0) })
    }

    private struct Persisted: Codable {
        var blockedRequestsSession: Int?
        var httpsUpgradesSession: Int?
        var cookiesBlockedSession: Int?
        var timeSavedMillisecondsSession: Int?
        var blockedRequestsLifetime: Int
        var httpsUpgradesLifetime: Int
        var cookiesBlockedLifetime: Int
        var timeSavedMillisecondsLifetime: Int?

        enum CodingKeys: String, CodingKey {
            case blockedRequestsSession
            case httpsUpgradesSession
            case cookiesBlockedSession
            case timeSavedMillisecondsSession
            case blockedRequestsLifetime
            case httpsUpgradesLifetime
            case cookiesBlockedLifetime
            case timeSavedMillisecondsLifetime
        }

        init(
            blockedRequestsSession: Int,
            httpsUpgradesSession: Int,
            cookiesBlockedSession: Int,
            timeSavedMillisecondsSession: Int,
            blockedRequestsLifetime: Int,
            httpsUpgradesLifetime: Int,
            cookiesBlockedLifetime: Int,
            timeSavedMillisecondsLifetime: Int
        ) {
            self.blockedRequestsSession = blockedRequestsSession
            self.httpsUpgradesSession = httpsUpgradesSession
            self.cookiesBlockedSession = cookiesBlockedSession
            self.timeSavedMillisecondsSession = timeSavedMillisecondsSession
            self.blockedRequestsLifetime = blockedRequestsLifetime
            self.httpsUpgradesLifetime = httpsUpgradesLifetime
            self.cookiesBlockedLifetime = cookiesBlockedLifetime
            self.timeSavedMillisecondsLifetime = timeSavedMillisecondsLifetime
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            blockedRequestsSession = try container.decodeIfPresent(Int.self, forKey: .blockedRequestsSession)
            httpsUpgradesSession = try container.decodeIfPresent(Int.self, forKey: .httpsUpgradesSession)
            cookiesBlockedSession = try container.decodeIfPresent(Int.self, forKey: .cookiesBlockedSession)
            timeSavedMillisecondsSession = try container.decodeIfPresent(Int.self, forKey: .timeSavedMillisecondsSession)
            blockedRequestsLifetime = try container.decode(Int.self, forKey: .blockedRequestsLifetime)
            httpsUpgradesLifetime = try container.decode(Int.self, forKey: .httpsUpgradesLifetime)
            cookiesBlockedLifetime = try container.decodeIfPresent(Int.self, forKey: .cookiesBlockedLifetime) ?? 0
            timeSavedMillisecondsLifetime = try container.decodeIfPresent(Int.self, forKey: .timeSavedMillisecondsLifetime)
        }
    }

    private func persist() {
        let data = Persisted(
            blockedRequestsSession: blockedRequestsSession,
            httpsUpgradesSession: httpsUpgradesSession,
            cookiesBlockedSession: cookiesBlockedSession,
            timeSavedMillisecondsSession: timeSavedMillisecondsSession,
            blockedRequestsLifetime: blockedRequestsLifetime,
            httpsUpgradesLifetime: httpsUpgradesLifetime,
            cookiesBlockedLifetime: cookiesBlockedLifetime,
            timeSavedMillisecondsLifetime: timeSavedMillisecondsLifetime
        )
        try? JSONFileStore.save(data, to: fileName)
    }
}
