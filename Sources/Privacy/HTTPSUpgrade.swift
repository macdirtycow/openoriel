import Foundation

enum HTTPSUpgrade {
    /// Upgrades http → https when safe heuristics allow. Does not upgrade localhost or IP literals.
    static func upgradeIfNeeded(_ url: URL, enabled: Bool) -> (url: URL, didUpgrade: Bool) {
        guard enabled else { return (url, false) }
        guard url.scheme?.lowercased() == "http" else { return (url, false) }
        guard let host = url.host?.lowercased(), !host.isEmpty else { return (url, false) }
        if host == "localhost" || host.hasSuffix(".local") { return (url, false) }
        if host.allSatisfy({ $0.isNumber || $0 == "." }) { return (url, false) } // IPv4-ish

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = "https"
        guard let upgraded = components?.url else { return (url, false) }
        return (upgraded, true)
    }
}
