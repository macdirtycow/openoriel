import Foundation
import Observation

/// Session and lifetime privacy counters. Blocked-request totals are best-effort
/// (WebKit does not expose a full content-blocker hit stream for in-app rule lists).
@Observable
@MainActor
final class PrivacyStats {
    private(set) var blockedRequestsSession: Int = 0
    private(set) var httpsUpgradesSession: Int = 0
    private(set) var blockedRequestsLifetime: Int = 0
    private(set) var httpsUpgradesLifetime: Int = 0

    private let fileName = "privacy-stats.json"

    init() {
        if let loaded = try? JSONFileStore.load(Persisted.self, from: fileName) {
            blockedRequestsLifetime = loaded.blockedRequestsLifetime
            httpsUpgradesLifetime = loaded.httpsUpgradesLifetime
        }
    }

    func recordBlockedRequest(count: Int = 1) {
        guard count > 0 else { return }
        blockedRequestsSession += count
        blockedRequestsLifetime += count
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
    }

    private struct Persisted: Codable {
        var blockedRequestsLifetime: Int
        var httpsUpgradesLifetime: Int
    }

    private func persist() {
        let data = Persisted(
            blockedRequestsLifetime: blockedRequestsLifetime,
            httpsUpgradesLifetime: httpsUpgradesLifetime
        )
        try? JSONFileStore.save(data, to: fileName)
    }
}
