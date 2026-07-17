import Foundation
import Observation
import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable, Codable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum NewTabBehavior: String, CaseIterable, Identifiable, Codable, Sendable {
    case startPage
    case homepage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .startPage: "Start page"
        case .homepage: "Homepage URL"
        }
    }
}

@Observable
@MainActor
final class BrowserSettings {
    var searchEngine: SearchEngine {
        didSet { persistSearchEngine() }
    }

    var restorePreviousSession: Bool {
        didSet { defaults.set(restorePreviousSession, forKey: restoreSessionKey) }
    }

    var appearance: AppAppearance {
        didSet { defaults.set(appearance.rawValue, forKey: appearanceKey) }
    }

    var newTabBehavior: NewTabBehavior {
        didSet { defaults.set(newTabBehavior.rawValue, forKey: newTabBehaviorKey) }
    }

    var homepageURLString: String {
        didSet { defaults.set(homepageURLString, forKey: homepageKey) }
    }

    var homepageURL: URL {
        if let url = URL(string: homepageURLString), url.scheme != nil {
            return url
        }
        return BrowserConstants.productWebsiteURL
    }

    private let defaults: UserDefaults
    private let searchEngineKey = "oriel.searchEngine"
    private let restoreSessionKey = "oriel.restoreSession"
    private let appearanceKey = "oriel.appearance"
    private let newTabBehaviorKey = "oriel.newTabBehavior"
    private let homepageKey = "oriel.homepageURL"

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
        if let raw = defaults.string(forKey: appearanceKey),
           let mode = AppAppearance(rawValue: raw) {
            self.appearance = mode
        } else {
            self.appearance = .system
        }
        if let raw = defaults.string(forKey: newTabBehaviorKey),
           let behavior = NewTabBehavior(rawValue: raw) {
            self.newTabBehavior = behavior
        } else {
            self.newTabBehavior = .startPage
        }
        self.homepageURLString = defaults.string(forKey: homepageKey)
            ?? BrowserConstants.productWebsiteURL.absoluteString
    }

    private func persistSearchEngine() {
        defaults.set(searchEngine.rawValue, forKey: searchEngineKey)
    }
}
