import Foundation

/// One installable item from Chrome Web Store or Firefox AMO, for Oriel’s native store UI.
struct ExtensionStoreItem: Identifiable, Hashable, Sendable {
    enum Source: String, Hashable, Sendable {
        case chrome
        case firefox
    }

    enum Kind: String, Hashable, Sendable {
        case `extension`
        case theme
    }

    /// Stable id: `chrome:<storeID>` or `firefox:<slug>`.
    var id: String { "\(source.rawValue):\(storeIdentifier)" }

    let source: Source
    let kind: Kind
    /// Chrome: 32-char a–p id. Firefox: AMO slug.
    let storeIdentifier: String
    let name: String
    let summary: String
    let iconURL: URL?
    let rating: Double?
    let storeURL: URL?
}

/// Fetches searchable catalogs for the native Oriel Store.
enum ExtensionStoreCatalog {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 30
        config.waitsForConnectivity = true
        config.httpAdditionalHeaders = [
            "Accept-Language": "en-US,en;q=0.9"
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Public

    static func search(
        query: String,
        source: ExtensionStoreItem.Source,
        kind: ExtensionStoreItem.Kind,
        limit: Int = 30
    ) async throws -> [ExtensionStoreItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        switch source {
        case .firefox:
            return try await searchFirefox(query: trimmed, kind: kind, limit: limit)
        case .chrome:
            return try await searchChrome(query: trimmed, kind: kind, limit: limit)
        }
    }

    // MARK: - Firefox AMO (official API v5)

    static func searchFirefox(
        query: String,
        kind: ExtensionStoreItem.Kind,
        limit: Int
    ) async throws -> [ExtensionStoreItem] {
        var components = URLComponents(string: "https://addons.mozilla.org/api/v5/addons/search/")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "app", value: "firefox"),
            URLQueryItem(name: "page_size", value: String(min(max(limit, 1), 50))),
            URLQueryItem(name: "type", value: kind == .theme ? "statictheme" : "extension"),
            URLQueryItem(name: "lang", value: "en-US")
        ]
        if query.isEmpty {
            items.append(URLQueryItem(name: "sort", value: "users"))
        } else {
            items.append(URLQueryItem(name: "q", value: query))
            items.append(URLQueryItem(name: "sort", value: "relevance"))
        }
        components.queryItems = items
        guard let url = components.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Oriel/\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") (extension store)",
            forHTTPHeaderField: "User-Agent"
        )
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let parsed = parseAMOSearch(data: data, kind: kind)
            if !parsed.isEmpty {
                return Array(parsed.prefix(limit))
            }
        } catch {
            // Fall through to curated list so the store is never blank offline.
            if !query.isEmpty { throw error }
        }

        let fallback = curatedFallback(source: .firefox, kind: kind, query: query)
        if fallback.isEmpty { throw URLError(.cannotParseResponse) }
        return Array(fallback.prefix(limit))
    }

    static func parseAMOSearch(data: Data, kind: ExtensionStoreItem.Kind) -> [ExtensionStoreItem] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = root["results"] as? [[String: Any]] else {
            return []
        }
        return results.compactMap { row in
            guard let slug = row["slug"] as? String, !slug.isEmpty else { return nil }
            let name = localizedString(row["name"]) ?? slug
            let summary = localizedString(row["summary"]) ?? ""
            let icon: URL? = {
                if let s = row["icon_url"] as? String { return URL(string: s) }
                return nil
            }()
            let rating: Double? = {
                guard let ratings = row["ratings"] as? [String: Any] else { return nil }
                if let d = ratings["average"] as? Double { return d }
                if let n = ratings["average"] as? NSNumber { return n.doubleValue }
                return nil
            }()
            let storeURL = URL(string: "https://addons.mozilla.org/firefox/addon/\(slug)/")
            let resolvedKind: ExtensionStoreItem.Kind = {
                if let type = row["type"] as? String, type == "statictheme" { return .theme }
                return kind
            }()
            return ExtensionStoreItem(
                source: .firefox,
                kind: resolvedKind,
                storeIdentifier: slug,
                name: name,
                summary: summary,
                iconURL: icon,
                rating: rating,
                storeURL: storeURL
            )
        }
    }

    private static func localizedString(_ value: Any?) -> String? {
        if let s = value as? String, !s.isEmpty { return s }
        guard let map = value as? [String: Any] else { return nil }
        let preferred = Locale.current.identifier.replacingOccurrences(of: "_", with: "-")
        if let s = map[preferred] as? String, !s.isEmpty { return s }
        let lang = Locale.current.language.languageCode?.identifier
        if let lang, let s = map[lang] as? String, !s.isEmpty { return s }
        if let s = map["en-US"] as? String, !s.isEmpty { return s }
        return map.values.compactMap { $0 as? String }.first { !$0.isEmpty }
    }

    // MARK: - Chrome Web Store (HTML + embedded payload; no official public API)

    static func searchChrome(
        query: String,
        kind: ExtensionStoreItem.Kind,
        limit: Int
    ) async throws -> [ExtensionStoreItem] {
        let urls = chromeCatalogURLs(query: query, kind: kind)
        var lastError: Error?
        for url in urls {
            do {
                let html = try await fetchChromeHTML(url)
                let items = parseChromeStoreHTML(html, kind: kind)
                if !items.isEmpty {
                    return Array(items.prefix(limit))
                }
            } catch {
                lastError = error
            }
        }

        let fallback = curatedFallback(source: .chrome, kind: kind, query: query)
        if !fallback.isEmpty {
            return Array(fallback.prefix(limit))
        }
        throw lastError ?? URLError(.cannotParseResponse)
    }

    /// Candidate CWS pages — first non-empty parse wins.
    static func chromeCatalogURLs(query: String, kind: ExtensionStoreItem.Kind) -> [URL] {
        var urls: [URL] = []
        if query.isEmpty {
            if kind == .theme {
                urls.append(contentsOf: [
                    URL(string: "https://chromewebstore.google.com/category/themes?hl=en&gl=US")!,
                    URL(string: "https://chromewebstore.google.com/search/theme?hl=en&gl=US&itemTypes=2")!
                ])
            } else {
                urls.append(contentsOf: [
                    URL(string: "https://chromewebstore.google.com/category/extensions?hl=en&gl=US")!,
                    URL(string: "https://chromewebstore.google.com/category/extensions/make_chrome_yours/privacy?hl=en&gl=US")!,
                    URL(string: "https://chromewebstore.google.com/search/extension?hl=en&gl=US")!
                ])
            }
        } else {
            let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? query
            var components = URLComponents(string: "https://chromewebstore.google.com/search/\(encoded)")!
            var items = [
                URLQueryItem(name: "hl", value: "en"),
                URLQueryItem(name: "gl", value: "US")
            ]
            if kind == .theme {
                items.append(URLQueryItem(name: "itemTypes", value: "2"))
            }
            components.queryItems = items
            if let built = components.url { urls.append(built) }
        }
        return urls
    }

    private static func fetchChromeHTML(_ url: URL) async throws -> String {
        var request = URLRequest(url: url)
        request.setValue(UserAgentPolicy.chromeDesktop, forHTTPHeaderField: "User-Agent")
        request.setValue(
            "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            forHTTPHeaderField: "Accept"
        )
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.setValue("https://chromewebstore.google.com/", forHTTPHeaderField: "Referer")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw URLError(.badServerResponse)
        }
        return html
    }

    /// Parses CWS search/category HTML cards and embedded `AF_initDataCallback` payloads.
    static func parseChromeStoreHTML(_ html: String, kind: ExtensionStoreItem.Kind) -> [ExtensionStoreItem] {
        var results: [ExtensionStoreItem] = []
        var seen = Set<String>()

        func append(_ item: ExtensionStoreItem) {
            guard !seen.contains(item.storeIdentifier) else { return }
            seen.insert(item.storeIdentifier)
            results.append(item)
        }

        // 1) Embedded payload — survives markup churn / partial SSR.
        // Shape: ["<32-char-id>","https://…icon…","Title",4.5,…]
        // Use a raw string so `"` matches a quote (never write #"…\"…"# — that matches \").
        let embeddedPattern =
            #""([a-p]{32})","(https://[^"]+)","((?:\\.|[^"\\]){2,120})",([0-9]+(?:\.[0-9]+)?)"#
        if let regex = try? NSRegularExpression(pattern: embeddedPattern) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 5,
                      let idRange = Range(match.range(at: 1), in: html),
                      let iconRange = Range(match.range(at: 2), in: html),
                      let nameRange = Range(match.range(at: 3), in: html),
                      let ratingRange = Range(match.range(at: 4), in: html) else { continue }
                let storeID = String(html[idRange])
                guard ChromeWebStoreAPI.isValidExtensionID(storeID) else { continue }
                let iconURL = URL(string: String(html[iconRange]))
                let name = decodeJSONString(String(html[nameRange]))
                let rating = Double(String(html[ratingRange]))
                let summary = chromeSummaryNearEmbeddedID(html: html, storeID: storeID) ?? ""
                append(
                    ExtensionStoreItem(
                        source: .chrome,
                        kind: kind,
                        storeIdentifier: storeID,
                        name: name,
                        summary: summary,
                        iconURL: iconURL,
                        rating: rating,
                        storeURL: URL(string: "https://chromewebstore.google.com/detail/\(storeID)")
                    )
                )
            }
        }

        // 2) data-item-id cards (richer title text nearby).
        // NOTE: do not use #"…\"…"# — in Swift raw strings that matches a literal backslash.
        let idPattern = "data-item-id=\"([a-p]{32})\""
        if let regex = try? NSRegularExpression(pattern: idPattern) {
            let ns = html as NSString
            let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
            for match in matches {
                guard match.numberOfRanges >= 2,
                      let idRange = Range(match.range(at: 1), in: html) else { continue }
                let storeID = String(html[idRange])
                guard ChromeWebStoreAPI.isValidExtensionID(storeID) else { continue }
                if seen.contains(storeID) {
                    // Upgrade existing row with card title/summary/icon when richer.
                    continue
                }
                let start = match.range.location
                let end = min(ns.length, start + 2200)
                let chunk = ns.substring(with: NSRange(location: start, length: end - start))
                append(chromeItem(fromCardChunk: chunk, storeID: storeID, kind: kind))
            }
        }

        // 3) Fallback: /detail/<slug>/<id> or ./detail/<slug>/<id>
        if results.isEmpty {
            let detailPattern = "\\.?/detail/([A-Za-z0-9\\-]+)/([a-p]{32})"
            if let regex = try? NSRegularExpression(pattern: detailPattern) {
                let ns = html as NSString
                let matches = regex.matches(in: html, range: NSRange(location: 0, length: ns.length))
                for match in matches {
                    guard match.numberOfRanges >= 3,
                          let slugRange = Range(match.range(at: 1), in: html),
                          let idRange = Range(match.range(at: 2), in: html) else { continue }
                    let slug = String(html[slugRange])
                    let storeID = String(html[idRange])
                    guard ChromeWebStoreAPI.isValidExtensionID(storeID) else { continue }
                    let name = slug
                        .replacingOccurrences(of: "-", with: " ")
                        .split(separator: " ")
                        .map(\.capitalized)
                        .joined(separator: " ")
                    append(
                        ExtensionStoreItem(
                            source: .chrome,
                            kind: kind,
                            storeIdentifier: storeID,
                            name: name,
                            summary: "",
                            iconURL: nil,
                            rating: nil,
                            storeURL: URL(string: "https://chromewebstore.google.com/detail/\(slug)/\(storeID)")
                        )
                    )
                }
            }
        }

        return results
    }

    private static func decodeJSONString(_ raw: String) -> String {
        if let data = "\"\(raw)\"".data(using: .utf8),
           let decoded = try? JSONDecoder().decode(String.self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return raw
            .replacingOccurrences(of: "\\u0026", with: "&")
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\/", with: "/")
    }

    /// Best-effort summary string that often follows the rating fields in the embedded tuple.
    private static func chromeSummaryNearEmbeddedID(html: String, storeID: String) -> String? {
        let pattern =
            "\"\(NSRegularExpression.escapedPattern(for: storeID))\",\"https://[^\"]+\",\"(?:\\\\.|[^\"\\\\])+\",[0-9.]+,[0-9]+,\"https://[^\"]+\",\"((?:\\\\.|[^\"\\\\]){12,160})\""
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: html, range: NSRange(location: 0, length: (html as NSString).length)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return decodeJSONString(String(html[range]))
    }

    private static func chromeItem(
        fromCardChunk chunk: String,
        storeID: String,
        kind: ExtensionStoreItem.Kind
    ) -> ExtensionStoreItem {
        let texts = chunk
            .replacingOccurrences(of: "<[^>]+>", with: "\n", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let skip: Set<String> = [
            "Featured", "Remove", "Add to Chrome", "Toevoegen aan Chrome",
            "Verwijderen", "OK", "Sponsored", "Add to Oriel"
        ]
        let title = texts.first(where: { text in
            guard text.count >= 2, text.count <= 80 else { return false }
            if skip.contains(text) { return false }
            if Double(text) != nil { return false }
            if text.hasSuffix(".org") || text.hasSuffix(".com") || text.hasPrefix("www.") { return false }
            if text.allSatisfy({ $0.isNumber || $0 == "." || $0 == "," || $0 == "+" }) { return false }
            return true
        }) ?? humanizeChromeSlug(from: chunk, storeID: storeID, kind: kind)

        let summary = texts.dropFirst().first(where: { text in
            text.count >= 12 && text.count <= 160
                && !skip.contains(text)
                && Double(text) == nil
                && text != title
        }) ?? ""

        let iconURL: URL? = {
            let pattern = "src=\"(https://lh3\\.googleusercontent\\.com/[^\"]+)\""
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: chunk, range: NSRange(location: 0, length: (chunk as NSString).length)),
                  match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: chunk) else {
                return nil
            }
            return URL(string: String(chunk[range]))
        }()

        let slug = chromeSlug(from: chunk, storeID: storeID)
        let storeURL: URL? = {
            if let slug, !slug.isEmpty {
                return URL(string: "https://chromewebstore.google.com/detail/\(slug)/\(storeID)")
            }
            return URL(string: "https://chromewebstore.google.com/detail/\(storeID)")
        }()

        return ExtensionStoreItem(
            source: .chrome,
            kind: kind,
            storeIdentifier: storeID,
            name: title,
            summary: summary,
            iconURL: iconURL,
            rating: nil,
            storeURL: storeURL
        )
    }

    private static func chromeSlug(from chunk: String, storeID: String) -> String? {
        let pattern = "\\.?/detail/([A-Za-z0-9\\-]+)/\(NSRegularExpression.escapedPattern(for: storeID))"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: chunk, range: NSRange(location: 0, length: (chunk as NSString).length)),
              match.numberOfRanges >= 2,
              let range = Range(match.range(at: 1), in: chunk) else {
            return nil
        }
        return String(chunk[range])
    }

    private static func humanizeChromeSlug(
        from chunk: String,
        storeID: String,
        kind: ExtensionStoreItem.Kind
    ) -> String {
        if let slug = chromeSlug(from: chunk, storeID: storeID) {
            return slug
                .replacingOccurrences(of: "-", with: " ")
                .split(separator: " ")
                .map(\.capitalized)
                .joined(separator: " ")
        }
        return kind == .theme ? "Chrome theme" : "Chrome extension"
    }

    // MARK: - Curated fallback (never leave the store blank)

    /// Popular installable items used when live catalog fetch/parse fails.
    static func curatedFallback(
        source: ExtensionStoreItem.Source,
        kind: ExtensionStoreItem.Kind,
        query: String
    ) -> [ExtensionStoreItem] {
        let all: [ExtensionStoreItem]
        switch (source, kind) {
        case (.chrome, .extension):
            all = [
                item(.chrome, .extension, "cjpalhdlnbpafiamejdnhcphjbkeiagm", "uBlock Origin", "Efficient ad blocker."),
                item(.chrome, .extension, "eimadpbcbfnmbkopoojfekhnkhdbieeh", "Dark Reader", "Dark mode for every website."),
                item(.chrome, .extension, "nngceckbapebfimnlniiiahkandclblb", "Bitwarden", "Password manager."),
                item(.chrome, .extension, "hdokiejnpimakedhajhdlcegeplioahd", "LastPass", "Password manager."),
                item(.chrome, .extension, "bkdgflcldnnnapblkhphbgpggdiikppg", "DuckDuckGo Privacy", "Privacy essentials."),
                item(.chrome, .extension, "gighmmpiobklfepjocnamgkkbiglidom", "AdBlock", "Block ads on the web."),
                item(.chrome, .extension, "cfhdojbkjhnklbpkdaibdccddilifddb", "Adblock Plus", "Block ads."),
                item(.chrome, .extension, "fmkadmapgofadopljbjfkapdkoienihi", "React Developer Tools", "Debug React apps."),
                item(.chrome, .extension, "lmhkpmbekcpmknklioeibfkpmmfibljd", "Redux DevTools", "Debug Redux apps."),
                item(.chrome, .extension, "ghbmnnjooekpmoecnnnilnnbdlolhkhi", "Google Docs Offline", "Edit Docs offline.")
            ]
        case (.chrome, .theme):
            all = [
                item(.chrome, .theme, "ookepigabmicjpgfnmncjiplegcacdbm", "Material Simple Dark Grey", "Dark grey Material theme."),
                item(.chrome, .theme, "faeadnfmdfamenfhaipofoffijhlnkif", "Into The Black Hole", "True AMOLED black theme."),
                item(.chrome, .theme, "eeffcpnmcmfdfnaadpnkldhkcjjiihcf", "Deep Dark", "Deep dark Chrome theme."),
                item(.chrome, .theme, "ijliejcnnlephngnfmfefepancofbbom", "Spring Flowers", "Floral light theme."),
                item(.chrome, .theme, "lipkgklkkoiammeadbcpmhbppdhaecdi", "Marguerite Flowers", "Soft flower theme.")
            ]
        case (.firefox, .extension):
            all = [
                item(.firefox, .extension, "ublock-origin", "uBlock Origin", "Efficient ad blocker."),
                item(.firefox, .extension, "darkreader", "Dark Reader", "Dark mode for every website."),
                item(.firefox, .extension, "bitwarden-password-manager", "Bitwarden", "Password manager."),
                item(.firefox, .extension, "duckduckgo-for-firefox", "DuckDuckGo Privacy Essentials", "Privacy essentials."),
                item(.firefox, .extension, "sponsorblock", "SponsorBlock", "Skip YouTube sponsors."),
                item(.firefox, .extension, "privacy-badger17", "Privacy Badger", "Automatically block trackers."),
                item(.firefox, .extension, "firefox-translations", "Firefox Translations", "Translate pages locally."),
                item(.firefox, .extension, "clearurls", "ClearURLs", "Remove tracking from URLs.")
            ]
        case (.firefox, .theme):
            all = [
                item(.firefox, .theme, "activist-balanced_", "Activist – Balanced", "Colorways theme."),
                item(.firefox, .theme, "visionary-balanced", "Visionary – Balanced", "Colorways theme."),
                item(.firefox, .theme, "dreamer-balanced", "Dreamer – Balanced", "Colorways theme."),
                item(.firefox, .theme, "lush-soft", "Lush – Soft", "Soft green theme."),
                item(.firefox, .theme, "nicothin-space", "Dark space", "Dynamic space theme.")
            ]
        }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.name.lowercased().contains(q)
                || $0.summary.lowercased().contains(q)
                || $0.storeIdentifier.lowercased().contains(q)
        }
    }

    private static func item(
        _ source: ExtensionStoreItem.Source,
        _ kind: ExtensionStoreItem.Kind,
        _ id: String,
        _ name: String,
        _ summary: String
    ) -> ExtensionStoreItem {
        let storeURL: URL? = {
            switch source {
            case .chrome:
                return URL(string: "https://chromewebstore.google.com/detail/\(id)")
            case .firefox:
                return URL(string: "https://addons.mozilla.org/firefox/addon/\(id)/")
            }
        }()
        return ExtensionStoreItem(
            source: source,
            kind: kind,
            storeIdentifier: id,
            name: name,
            summary: summary,
            iconURL: nil,
            rating: nil,
            storeURL: storeURL
        )
    }
}
