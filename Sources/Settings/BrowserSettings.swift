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

    var accentTheme: BrowserAccentTheme {
        didSet { defaults.set(accentTheme.rawValue, forKey: accentThemeKey) }
    }

    var backgroundTheme: BrowserBackgroundTheme {
        didSet { defaults.set(backgroundTheme.rawValue, forKey: backgroundThemeKey) }
    }

    var newTabBehavior: NewTabBehavior {
        didSet { defaults.set(newTabBehavior.rawValue, forKey: newTabBehaviorKey) }
    }

    var homepageURLString: String {
        didSet { defaults.set(homepageURLString, forKey: homepageKey) }
    }

    /// Default for new tabs; existing tabs keep their own toggle until changed.
    var javaScriptEnabledByDefault: Bool {
        didSet { defaults.set(javaScriptEnabledByDefault, forKey: javaScriptKey) }
    }

    /// When true, audio/video require a user gesture before playing.
    var blockAutoplay: Bool {
        didSet { defaults.set(blockAutoplay, forKey: blockAutoplayKey) }
    }

    /// Strip known tracking query parameters (utm_*, fbclid, gclid, …) when loading pages.
    var stripTrackingParameters: Bool {
        didSet { defaults.set(stripTrackingParameters, forKey: stripTrackingKey) }
    }

    /// First-launch product tour completed.
    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: onboardingKey) }
    }

    var homepageURL: URL {
        if let url = URL(string: homepageURLString), url.scheme != nil {
            return url
        }
        return BrowserConstants.productWebsiteURL
    }

    var brandColor: Color {
        OrielTheme.brandPrimary(accent: accentTheme)
    }

    private let defaults: UserDefaults
    private let searchEngineKey = "oriel.searchEngine"
    private let restoreSessionKey = "oriel.restoreSession"
    private let appearanceKey = "oriel.appearance"
    private let accentThemeKey = "oriel.accentTheme"
    private let backgroundThemeKey = "oriel.backgroundTheme"
    private let newTabBehaviorKey = "oriel.newTabBehavior"
    private let homepageKey = "oriel.homepageURL"
    private let javaScriptKey = "oriel.javaScriptEnabled"
    private let blockAutoplayKey = "oriel.blockAutoplay"
    private let stripTrackingKey = "oriel.stripTrackingParameters"
    private let onboardingKey = "oriel.hasCompletedOnboarding"

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
        if let raw = defaults.string(forKey: accentThemeKey),
           let theme = BrowserAccentTheme(rawValue: raw) {
            self.accentTheme = theme
        } else {
            self.accentTheme = .teal
        }
        if let raw = defaults.string(forKey: backgroundThemeKey),
           let theme = BrowserBackgroundTheme(rawValue: raw) {
            self.backgroundTheme = theme
        } else {
            self.backgroundTheme = .soft
        }
        if let raw = defaults.string(forKey: newTabBehaviorKey),
           let behavior = NewTabBehavior(rawValue: raw) {
            self.newTabBehavior = behavior
        } else {
            self.newTabBehavior = .startPage
        }
        self.homepageURLString = defaults.string(forKey: homepageKey)
            ?? BrowserConstants.productWebsiteURL.absoluteString
        if defaults.object(forKey: javaScriptKey) == nil {
            self.javaScriptEnabledByDefault = true
        } else {
            self.javaScriptEnabledByDefault = defaults.bool(forKey: javaScriptKey)
        }
        if defaults.object(forKey: blockAutoplayKey) == nil {
            self.blockAutoplay = true
        } else {
            self.blockAutoplay = defaults.bool(forKey: blockAutoplayKey)
        }
        if defaults.object(forKey: stripTrackingKey) == nil {
            self.stripTrackingParameters = true
        } else {
            self.stripTrackingParameters = defaults.bool(forKey: stripTrackingKey)
        }
        self.hasCompletedOnboarding = defaults.bool(forKey: onboardingKey)
        // Repair Soft/Paper/Sand stored with Dark (or Midnight with Light) from older builds.
        if let forced = backgroundTheme.forcedColorScheme {
            let repaired: AppAppearance = forced == .dark ? .dark : .light
            if (forced == .light && appearance == .dark) || (forced == .dark && appearance == .light) {
                appearance = repaired
            }
        }
    }

    private func persistSearchEngine() {
        defaults.set(searchEngine.rawValue, forKey: searchEngineKey)
    }
}
