import Foundation
import WebKit

enum ContentRuleValidationError: LocalizedError, Equatable {
    case empty
    case invalidJSON
    case notAnArray
    case missingTriggerOrAction
    case tooManyRules(Int)

    var errorDescription: String? {
        switch self {
        case .empty: "Ruleset is empty."
        case .invalidJSON: "Ruleset is not valid JSON."
        case .notAnArray: "Ruleset must be a JSON array."
        case .missingTriggerOrAction: "Each rule needs trigger and action objects."
        case .tooManyRules(let count): "Ruleset has \(count) rules; maximum for import is 50_000."
        }
    }
}

enum ContentRuleListValidator {
    static let maxRules = 50_000

    static func validate(_ data: Data) throws -> [[String: Any]] {
        guard !data.isEmpty else { throw ContentRuleValidationError.empty }
        let object = try JSONSerialization.jsonObject(with: data)
        guard let array = object as? [Any] else { throw ContentRuleValidationError.notAnArray }
        guard !array.isEmpty else { throw ContentRuleValidationError.empty }
        if array.count > maxRules {
            throw ContentRuleValidationError.tooManyRules(array.count)
        }

        var rules: [[String: Any]] = []
        for item in array {
            guard let rule = item as? [String: Any],
                  rule["trigger"] is [String: Any],
                  rule["action"] is [String: Any] else {
                throw ContentRuleValidationError.missingTriggerOrAction
            }
            rules.append(rule)
        }
        return rules
    }

    static func blockedHostHints(from rules: [[String: Any]]) -> [String] {
        var hints: [String] = []
        for rule in rules {
            guard let trigger = rule["trigger"] as? [String: Any],
                  let filter = trigger["url-filter"] as? String else { continue }
            let cleaned = filter
                .replacingOccurrences(of: ".*", with: "")
                .replacingOccurrences(of: "\\.", with: ".")
                .replacingOccurrences(of: "\\/", with: "/")
                .replacingOccurrences(of: "^", with: "")
                .replacingOccurrences(of: "$", with: "")
            if cleaned.contains("."), cleaned.count < 80, !cleaned.contains("*") {
                hints.append(cleaned.lowercased())
            }
        }
        return Array(Set(hints)).sorted()
    }
}

/// Compiles bundled EasyList / EasyPrivacy / cosmetic / YouTube rule lists.
@MainActor
@Observable
final class ContentBlockerManager {
    private(set) var compiledLists: [WKContentRuleList] = []
    private(set) var isReady = false
    private(set) var lastError: String?
    private(set) var ruleCount = 0
    private(set) var blockedHostHints: [String] = []
    private(set) var listNames: [String] = []
    /// Bumps when lists are (re)compiled so web views can re-attach.
    private(set) var generation: Int = 0
    private var cachedProbeHosts: [String] = TrackerHitProbe.seedHosts

    var compiledList: WKContentRuleList? { compiledLists.first }

    private let store = WKContentRuleListStore.default()
    private let compileIdentifierPrefix = "oriel.rules.v7"
    private let customListIdentifier = "oriel.rules.custom.v1"
    private let customListFileName = "custom-content-rules.json"
    private(set) var hasCustomFilterList = false

    func prepare() async {
        compiledLists = []
        listNames = []
        ruleCount = 0
        hasCustomFilterList = false

        let names = discoverBundledListNames()
        // Load + validate large JSON off the main actor so launch stays responsive.
        let payloads: [(name: String, data: Data)] = names.compactMap { name in
            guard let data = loadBundledJSON(named: name) else { return nil }
            return (name, data)
        }

        struct PreparedList: Sendable {
            var name: String
            var json: String
            var ruleCount: Int
            var hints: [String]
        }

        let prepared: (lists: [PreparedList], errors: [String]) = await Task.detached(priority: .userInitiated) {
            var lists: [PreparedList] = []
            var errors: [String] = []
            for item in payloads {
                do {
                    let rules = try ContentRuleListValidator.validate(item.data)
                    let json = String(data: item.data, encoding: .utf8) ?? "[]"
                    let hints = ContentRuleListValidator.blockedHostHints(from: rules)
                    lists.append(
                        PreparedList(
                            name: item.name,
                            json: json,
                            ruleCount: rules.count,
                            hints: hints
                        )
                    )
                } catch {
                    errors.append("\(item.name): \(error.localizedDescription)")
                }
            }
            return (lists, errors)
        }.value

        var lists: [WKContentRuleList] = []
        var loadedNames: [String] = []
        var totalRules = 0
        var hints: [String] = []
        var errors = prepared.errors
        var loadedPrimary = false

        for item in prepared.lists {
            do {
                let identifier = "\(compileIdentifierPrefix).\(item.name)"
                let list = try await compile(json: item.json, identifier: identifier)
                lists.append(list)
                loadedNames.append(item.name)
                totalRules += item.ruleCount
                hints.append(contentsOf: item.hints)
                if item.name != "example-blocklist" { loadedPrimary = true }
            } catch {
                errors.append("\(item.name): \(error.localizedDescription)")
            }
        }

        compiledLists = lists
        listNames = loadedNames
        ruleCount = totalRules
        blockedHostHints = Array(Set(hints)).sorted()
        cachedProbeHosts = makeTrackerProbeHosts(limit: 500)

        if let customData = try? Data(contentsOf: customRulesURL()), !customData.isEmpty {
            do {
                let customRules = try ContentRuleListValidator.validate(customData)
                let json = String(data: customData, encoding: .utf8) ?? "[]"
                let list = try await compile(json: json, identifier: customListIdentifier)
                compiledLists.append(list)
                listNames.append("custom")
                ruleCount += customRules.count
                blockedHostHints = Array(Set(blockedHostHints + ContentRuleListValidator.blockedHostHints(from: customRules))).sorted()
                cachedProbeHosts = makeTrackerProbeHosts(limit: 500)
                hasCustomFilterList = true
            } catch {
                errors.append("custom: \(error.localizedDescription)")
            }
        }

        isReady = !compiledLists.isEmpty
        lastError = isReady ? nil : (errors.last ?? ContentRuleValidationError.empty.errorDescription)
        if isReady, !loadedPrimary {
            lastError = "Using built-in fallback list (main lists failed to load)."
        }
        generation += 1
    }

    /// Import a Safari/WebKit content-blocker JSON array (EasyList-style converters OK).
    func importCustomFilterList(_ data: Data) async throws {
        _ = try ContentRuleListValidator.validate(data)
        try data.write(to: customRulesURL(), options: .atomic)
        await prepare()
    }

    func clearCustomFilterList() async {
        try? FileManager.default.removeItem(at: customRulesURL())
        hasCustomFilterList = false
        await prepare()
    }

    private func customRulesURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("Oriel", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(customListFileName)
    }

    func matchesBlockedHostHint(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        if !host.isEmpty {
            for domain in cachedProbeHosts where host == domain || host.hasSuffix("." + domain) {
                return true
            }
        }
        let haystack = url.absoluteString.lowercased()
        return blockedHostHints.contains { haystack.contains($0) }
    }

    /// Compact hostname list for the in-page tracker probe (seed + rule hints).
    func trackerProbeHosts(limit: Int = 500) -> [String] {
        if cachedProbeHosts.count <= limit { return cachedProbeHosts }
        return Array(cachedProbeHosts.prefix(limit))
    }

    private func makeTrackerProbeHosts(limit: Int) -> [String] {
        var set = Set(TrackerHitProbe.seedHosts)
        for hint in blockedHostHints {
            if let domain = Self.normalizedDomainHint(hint) {
                set.insert(domain)
            }
        }
        return Array(set).sorted().prefix(limit).map { String($0) }
    }

    private static func normalizedDomainHint(_ raw: String) -> String? {
        var hint = raw.lowercased()
            .replacingOccurrences(of: #"^[^:]+://\+?\(?\^?[^:]+\.\)\?"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[/:\]$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\[/:].*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^\(\?:?\.\*\)\??"#, with: "", options: .regularExpression)
        hint = hint.trimmingCharacters(in: CharacterSet(charactersIn: "./"))
        // Prefer simple domain-like tokens: ads.example.com
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard hint.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        guard hint.contains("."), hint.count >= 4, hint.count <= 64 else { return nil }
        if hint.hasPrefix(".") || hint.hasSuffix(".") || hint.contains("..") { return nil }
        return hint
    }

    func validateImport(_ data: Data) throws -> Int {
        try ContentRuleListValidator.validate(data).count
    }

    func apply(to webView: WKWebView, enabled: Bool) {
        let ucc = webView.configuration.userContentController
        ucc.removeAllContentRuleLists()
        guard enabled else { return }
        for list in compiledLists {
            ucc.add(list)
        }
    }

    /// Prefer EasyList → EasyPrivacy → cosmetic → YouTube; fallback last.
    private func discoverBundledListNames() -> [String] {
        let urls =
            Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "ContentBlocker")
            ?? Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil)
            ?? []

        let names = urls.compactMap { url -> String? in
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("oriel-") || name == "example-blocklist" else { return nil }
            return name
        }

        let primary = names.filter { $0.hasPrefix("oriel-") }.sorted { lhs, rhs in
            listSortKey(lhs) < listSortKey(rhs)
        }
        if primary.isEmpty {
            return names.contains("example-blocklist") ? ["example-blocklist"] : []
        }
        return primary
    }

    private func listSortKey(_ name: String) -> (Int, String) {
        let order: [(String, Int)] = [
            ("oriel-base", 0),
            ("oriel-ads", 1),
            ("oriel-privacy", 2),
            ("oriel-annoyances", 3),
            ("oriel-site-fixes", 4),
            ("oriel-youtube-ads", 5),
            // Legacy names (if present)
            ("oriel-easylist", 10),
            ("oriel-easyprivacy", 11),
            ("oriel-cosmetic", 12),
        ]
        for (prefix, rank) in order where name.hasPrefix(prefix) {
            return (rank, name)
        }
        return (50, name)
    }

    private func loadBundledJSON(named name: String) -> Data? {
        let url = Bundle.main.url(forResource: name, withExtension: "json", subdirectory: "ContentBlocker")
            ?? Bundle.main.url(forResource: name, withExtension: "json")
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }

    private func compile(json: String, identifier: String) async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            store?.compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: json
            ) { list, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let list {
                    continuation.resume(returning: list)
                } else {
                    continuation.resume(throwing: ContentRuleValidationError.invalidJSON)
                }
            }
        }
    }
}
