import Foundation

/// Resolves favicon URLs for tab chrome (DuckDuckGo icon service — no Google dependency).
enum FaviconResolver {
    static func iconURL(for pageURL: URL?, size: Int = 64) -> URL? {
        guard let host = pageURL?.host?.lowercased(), !host.isEmpty else { return nil }
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: ".-")
        let safe = host.unicodeScalars.map { allowed.contains($0) ? Character($0) : Character("-") }
        let cleaned = String(safe)
        return URL(string: "https://icons.duckduckgo.com/ip3/\(cleaned).ico")
    }
}
