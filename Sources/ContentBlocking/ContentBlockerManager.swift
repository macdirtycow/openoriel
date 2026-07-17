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

    /// Host substrings extracted from simple url-filter rules for navigation-level counting.
    static func blockedHostHints(from rules: [[String: Any]]) -> [String] {
        var hints: [String] = []
        for rule in rules {
            guard let trigger = rule["trigger"] as? [String: Any],
                  let filter = trigger["url-filter"] as? String else { continue }
            // Pull domain-like tokens from escaped filters: .*doubleclick\\.net
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

@MainActor
@Observable
final class ContentBlockerManager {
    private(set) var compiledList: WKContentRuleList?
    private(set) var isReady = false
    private(set) var lastError: String?
    private(set) var ruleCount = 0
    private(set) var blockedHostHints: [String] = []

    private let listIdentifier = "oriel.example-blocklist"
    private let store = WKContentRuleListStore.default()

    func prepare() async {
        do {
            let data = try loadBundledRuleset()
            let rules = try ContentRuleListValidator.validate(data)
            ruleCount = rules.count
            blockedHostHints = ContentRuleListValidator.blockedHostHints(from: rules)
            let json = String(data: data, encoding: .utf8) ?? "[]"
            compiledList = try await compile(json: json)
            isReady = compiledList != nil
            lastError = nil
        } catch {
            compiledList = nil
            isReady = false
            lastError = error.localizedDescription
        }
    }

    func matchesBlockedHostHint(_ url: URL) -> Bool {
        let haystack = url.absoluteString.lowercased()
        return blockedHostHints.contains { haystack.contains($0) }
    }

    /// Validates arbitrary imported JSON (future community lists).
    func validateImport(_ data: Data) throws -> Int {
        try ContentRuleListValidator.validate(data).count
    }

    private func loadBundledRuleset() throws -> Data {
        if let url = Bundle.main.url(forResource: "example-blocklist", withExtension: "json", subdirectory: "ContentBlocker")
            ?? Bundle.main.url(forResource: "example-blocklist", withExtension: "json") {
            return try Data(contentsOf: url)
        }
        throw ContentRuleValidationError.empty
    }

    private func compile(json: String) async throws -> WKContentRuleList {
        try await withCheckedThrowingContinuation { continuation in
            store?.compileContentRuleList(
                forIdentifier: listIdentifier,
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
