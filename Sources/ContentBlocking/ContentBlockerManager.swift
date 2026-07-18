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

/// Compiles bundled EasyList-derived + YouTube ad rules into `WKContentRuleList`s.
@MainActor
@Observable
final class ContentBlockerManager {
    private(set) var compiledLists: [WKContentRuleList] = []
    private(set) var isReady = false
    private(set) var lastError: String?
    private(set) var ruleCount = 0
    private(set) var blockedHostHints: [String] = []
    private(set) var listNames: [String] = []

    /// Convenience for call sites that still expect a single list — returns the first compiled list.
    var compiledList: WKContentRuleList? { compiledLists.first }

    private let store = WKContentRuleListStore.default()

    /// Load order matters: broad lists first, YouTube + OAuth allowlist last.
    private let bundledListNames = [
        "oriel-easylist",
        "oriel-youtube-ads",
        "example-blocklist" // fallback only if others missing
    ]

    func prepare() async {
        compiledLists = []
        listNames = []
        ruleCount = 0
        var hints: [String] = []
        var errors: [String] = []

        var loadedAnyPrimary = false
        for name in bundledListNames {
            if name == "example-blocklist", loadedAnyPrimary { continue }
            guard let data = loadBundledJSON(named: name) else { continue }
            do {
                let rules = try ContentRuleListValidator.validate(data)
                let json = String(data: data, encoding: .utf8) ?? "[]"
                let identifier = "oriel.\(name).v1"
                let list = try await compile(json: json, identifier: identifier)
                compiledLists.append(list)
                listNames.append(name)
                ruleCount += rules.count
                hints.append(contentsOf: ContentRuleListValidator.blockedHostHints(from: rules))
                if name != "example-blocklist" { loadedAnyPrimary = true }
            } catch {
                errors.append("\(name): \(error.localizedDescription)")
            }
        }

        blockedHostHints = Array(Set(hints)).sorted()
        isReady = !compiledLists.isEmpty
        lastError = isReady ? nil : (errors.last ?? ContentRuleValidationError.empty.errorDescription)

        // Prefer a short status when only fallback loaded.
        if isReady, !loadedAnyPrimary {
            lastError = "Using built-in fallback list (EasyList failed to load)."
        }
    }

    func matchesBlockedHostHint(_ url: URL) -> Bool {
        let haystack = url.absoluteString.lowercased()
        return blockedHostHints.contains { haystack.contains($0) }
    }

    func validateImport(_ data: Data) throws -> Int {
        try ContentRuleListValidator.validate(data).count
    }

    /// Apply or remove all compiled rule lists on a live web view (Shields toggle).
    func apply(to webView: WKWebView, enabled: Bool) {
        let ucc = webView.configuration.userContentController
        ucc.removeAllContentRuleLists()
        guard enabled else { return }
        for list in compiledLists {
            ucc.add(list)
        }
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
