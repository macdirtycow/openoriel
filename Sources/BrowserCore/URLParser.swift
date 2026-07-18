import Foundation

/// Resolves address-bar input into a navigable URL or search query.
enum URLParser: Sendable {
    enum Resolution: Equatable, Sendable {
        case url(URL)
        case search(query: String)
    }

    /// Schemes that must never be opened from the address bar or page navigation policy.
    static let rejectedSchemes: Set<String> = [
        "javascript",
        "data",
        "file",
        "about",
        "blob",
        "ws",
        "wss",
        "ftp"
    ]

    static let allowedSchemes: Set<String> = [
        "http",
        "https",
        BrowserConstants.aboutScheme
    ]

    static func resolve(_ rawInput: String, searchEngine: SearchEngine) -> URL {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return startPageURL
        }

        switch classify(trimmed) {
        case .url(let url):
            return url
        case .search(let query):
            return searchEngine.searchURL(for: query)
        }
    }

    static func classify(_ rawInput: String) -> Resolution {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .url(startPageURL)
        }

        if trimmed.lowercased() == "oriel:home" || trimmed.lowercased() == "about:home" {
            return .url(startPageURL)
        }

        if looksLikeSearchQuery(trimmed) {
            return .search(query: trimmed)
        }

        if let url = urlFromAddress(trimmed) {
            return .url(url)
        }

        return .search(query: trimmed)
    }

    static var startPageURL: URL {
        URL(string: "\(BrowserConstants.aboutScheme)://\(BrowserConstants.startPageHost)")!
    }

    static func isStartPage(_ url: URL?) -> Bool {
        guard let url else { return true }
        return url.scheme?.lowercased() == BrowserConstants.aboutScheme
            && url.host?.lowercased() == BrowserConstants.startPageHost
    }

    static func isDuckPlayerPage(_ url: URL?) -> Bool {
        guard let url else { return false }
        return url.scheme?.lowercased() == BrowserConstants.aboutScheme
            && url.host?.lowercased() == "player"
    }

    static func duckPlayerVideoID(from url: URL) -> String? {
        guard isDuckPlayerPage(url) else { return nil }
        let id = url.path.split(separator: "/").first.map(String.init)
        return id?.isEmpty == false ? id : nil
    }

    static func isAllowedNavigation(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        if rejectedSchemes.contains(scheme) { return false }
        return allowedSchemes.contains(scheme)
    }

    // MARK: - Private

    private static func looksLikeSearchQuery(_ input: String) -> Bool {
        if input.contains(" ") { return true }
        if input.contains("://") { return false }

        // Bracketed or bare IPv6 is a host, not a search.
        if looksLikeIPv6Literal(input) { return false }

        // Bare words without a dot are searches ("swift concurrency")
        if !input.contains(".") && !input.contains("localhost") && !input.contains(":") {
            return true
        }

        // Question-like queries
        if input.hasSuffix("?") { return true }

        return false
    }

    private static func urlFromAddress(_ input: String) -> URL? {
        if let url = URL(string: input), url.scheme != nil, url.host != nil {
            guard isAllowedNavigation(url) else { return nil }
            return url
        }

        // Prefer https for host-like input. Wrap bare IPv6 in brackets.
        let hostPart: String
        if looksLikeIPv6Literal(input), !input.hasPrefix("[") {
            hostPart = "[\(input)]"
        } else {
            hostPart = input
        }
        let candidate = hostPart.hasPrefix("//") ? "https:\(hostPart)" : "https://\(hostPart)"
        guard let url = URL(string: candidate),
              let host = url.host,
              isPlausibleHost(host),
              isAllowedNavigation(url) else {
            return nil
        }
        return url
    }

    private static func isPlausibleHost(_ host: String) -> Bool {
        if host.caseInsensitiveCompare("localhost") == .orderedSame { return true }
        // URL.host returns IPv6 without brackets.
        if host.contains(":") {
            return looksLikeIPv6Literal(host)
        }
        return host.contains(".")
    }

    /// Accepts standard IPv6 literals (with or without brackets).
    private static func looksLikeIPv6Literal(_ raw: String) -> Bool {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if host.hasPrefix("["), host.hasSuffix("]"), host.count > 2 {
            host = String(host.dropFirst().dropLast())
        }
        // Strip optional zone id (fe80::1%en0)
        if let zone = host.firstIndex(of: "%") {
            host = String(host[..<zone])
        }
        guard host.contains(":") else { return false }
        let allowed = CharacterSet(charactersIn: "0123456789abcdefABCDEF:")
        guard host.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        // Must look like hex groups separated by colons (including :: compression).
        let parts = host.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 3 else { return false }
        return parts.allSatisfy { part in
            part.isEmpty || (part.count <= 4 && part.unicodeScalars.allSatisfy { CharacterSet(charactersIn: "0123456789abcdefABCDEF").contains($0) })
        }
    }
}
