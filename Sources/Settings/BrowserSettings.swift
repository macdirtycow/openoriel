import Foundation
import Observation

@Observable
@MainActor
final class BrowserSettings {
    var searchEngine: SearchEngine {
        didSet { persist() }
    }

    var restorePreviousSession: Bool {
        didSet { defaults.set(restorePreviousSession, forKey: restoreSessionKey) }
    }

    private let defaults: UserDefaults
    private let searchEngineKey = "oriel.searchEngine"
    private let restoreSessionKey = "oriel.restoreSession"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: searchEngineKey),
           let engine = SearchEngine(rawValue: raw) {
            self.searchEngine = engine
        } else {
            self.searchEngine = .duckDuckGo
        }
        if defaults.object(forKey: restoreSessionKey) == nil {
            self.restorePreviousSession = true
        } else {
            self.restorePreviousSession = defaults.bool(forKey: restoreSessionKey)
        }
    }

    private func persist() {
        defaults.set(searchEngine.rawValue, forKey: searchEngineKey)
    }
}
