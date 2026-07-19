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

    /// Active Chrome/Firefox/Safari extension theme id, if any.
    var activeExtensionThemeID: String? {
        didSet {
            if let activeExtensionThemeID {
                defaults.set(activeExtensionThemeID, forKey: activeExtensionThemeKey)
            } else {
                defaults.removeObject(forKey: activeExtensionThemeKey)
            }
        }
    }

    /// Custom accent from an extension theme (RGB 0…1). Nil → built-in accent.
    var customAccentRGB: [Double]? {
        didSet {
            if let customAccentRGB {
                defaults.set(customAccentRGB, forKey: customAccentRGBKey)
            } else {
                defaults.removeObject(forKey: customAccentRGBKey)
            }
        }
    }

    /// Custom chrome / start-page base fill from an extension theme.
    var customBackgroundRGB: [Double]? {
        didSet {
            if let customBackgroundRGB {
                defaults.set(customBackgroundRGB, forKey: customBackgroundRGBKey)
            } else {
                defaults.removeObject(forKey: customBackgroundRGBKey)
            }
        }
    }

    /// When set by an extension theme, locks light/dark for contrast.
    var extensionThemePrefersDark: Bool? {
        didSet {
            if let extensionThemePrefersDark {
                defaults.set(extensionThemePrefersDark, forKey: extensionThemePrefersDarkKey)
            } else {
                defaults.removeObject(forKey: extensionThemePrefersDarkKey)
            }
        }
    }

    var brandColor: Color {
        if let rgb = customAccentRGB, rgb.count >= 3 {
            return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
        }
        return OrielTheme.brandPrimary(accent: accentTheme)
    }

    var customBackgroundColor: Color? {
        guard let rgb = customBackgroundRGB, rgb.count >= 3 else { return nil }
        return Color(red: rgb[0], green: rgb[1], blue: rgb[2])
    }

    var usesExtensionTheme: Bool {
        activeExtensionThemeID != nil && customAccentRGB != nil
    }

    func applyExtensionTheme(
        id: String,
        accentRGB: [Double],
        backgroundRGB: [Double],
        prefersDark: Bool
    ) {
        activeExtensionThemeID = id
        customAccentRGB = accentRGB
        customBackgroundRGB = backgroundRGB
        extensionThemePrefersDark = prefersDark
        appearance = prefersDark ? .dark : .light
    }

    func clearExtensionTheme() {
        activeExtensionThemeID = nil
        customAccentRGB = nil
        customBackgroundRGB = nil
        extensionThemePrefersDark = nil
        // Restore light/dark from the built-in background theme (extension themes force a scheme).
        if let forced = backgroundTheme.forcedColorScheme {
            appearance = forced == .dark ? .dark : .light
        } else {
            appearance = .system
        }
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
    private let activeExtensionThemeKey = "oriel.activeExtensionThemeID"
    private let customAccentRGBKey = "oriel.customAccentRGB"
    private let customBackgroundRGBKey = "oriel.customBackgroundRGB"
    private let extensionThemePrefersDarkKey = "oriel.extensionThemePrefersDark"

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
        self.activeExtensionThemeID = defaults.string(forKey: activeExtensionThemeKey)
        self.customAccentRGB = Self.doubleArray(from: defaults, key: customAccentRGBKey)
        self.customBackgroundRGB = Self.doubleArray(from: defaults, key: customBackgroundRGBKey)
        if defaults.object(forKey: extensionThemePrefersDarkKey) != nil {
            self.extensionThemePrefersDark = defaults.bool(forKey: extensionThemePrefersDarkKey)
        } else {
            self.extensionThemePrefersDark = nil
        }
        // Repair Soft/Paper/Sand stored with Dark (or Midnight with Light) from older builds.
        // Skip when an extension theme is driving appearance.
        if activeExtensionThemeID == nil, let forced = backgroundTheme.forcedColorScheme {
            let repaired: AppAppearance = forced == .dark ? .dark : .light
            if (forced == .light && appearance == .dark) || (forced == .dark && appearance == .light) {
                appearance = repaired
            }
        }
    }

    private func persistSearchEngine() {
        defaults.set(searchEngine.rawValue, forKey: searchEngineKey)
    }

    private static func doubleArray(from defaults: UserDefaults, key: String) -> [Double]? {
        guard let arr = defaults.array(forKey: key) else { return nil }
        let doubles = arr.compactMap { ($0 as? NSNumber)?.doubleValue }
        return doubles.count >= 3 ? Array(doubles.prefix(3)) : nil
    }
}
