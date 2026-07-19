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

    /// Classic Oriel vs Oriel Pulse (gaming-inspired edition in the same app).
    var edition: BrowserEdition {
        didSet {
            defaults.set(edition.rawValue, forKey: editionKey)
            applyEditionDefaultsIfNeeded(previous: nil)
        }
    }

    /// Soft cap on live WKWebViews when Pulse performance mode is on.
    var pulseWebViewLimit: Int {
        didSet {
            let clamped = min(16, max(4, pulseWebViewLimit))
            if clamped != pulseWebViewLimit {
                pulseWebViewLimit = clamped
                return
            }
            defaults.set(pulseWebViewLimit, forKey: pulseWebViewLimitKey)
            refreshPulsePoolLimit()
        }
    }

    /// When Pulse is active, prefer unloading idle background tabs more aggressively.
    var pulseAggressiveTabUnload: Bool {
        didSet {
            defaults.set(pulseAggressiveTabUnload, forKey: pulseAggressiveUnloadKey)
            refreshPulsePoolLimit()
        }
    }

    /// Block image resources via a WebKit content rule (Data Saver).
    var pulseDataSaver: Bool {
        didSet { defaults.set(pulseDataSaver, forKey: pulseDataSaverKey) }
    }

    /// When Low Power Mode is on, auto-tighten Pulse limits.
    var pulseBatterySaver: Bool {
        didSet { defaults.set(pulseBatterySaver, forKey: pulseBatterySaverKey) }
    }

    /// Show the persistent Pulse Corner panel when Pulse is active.
    var pulseCornerEnabled: Bool {
        didSet { defaults.set(pulseCornerEnabled, forKey: pulseCornerEnabledKey) }
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
        if edition.isPulse {
            return EditionBranding.pulseAccent
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

    /// Apply edition-preferred chrome when the user picks Pulse or Classic.
    func selectEdition(_ next: BrowserEdition, applySuggestedLook: Bool) {
        edition = next
        if applySuggestedLook, !usesExtensionTheme {
            accentTheme = next.preferredAccent
            backgroundTheme = next.preferredBackground
            if let forced = next.preferredBackground.forcedColorScheme {
                appearance = forced == .dark ? .dark : .light
            }
        }
        refreshPulsePoolLimit()
    }

    private func applyEditionDefaultsIfNeeded(previous: BrowserEdition?) {
        _ = previous
        refreshPulsePoolLimit()
    }

    func refreshPulsePoolLimitPublic() {
        refreshPulsePoolLimit()
    }

    private func refreshPulsePoolLimit() {
        if edition.isPulse {
            var limit = pulseAggressiveTabUnload ? pulseWebViewLimit : max(pulseWebViewLimit, 10)
            if pulseBatterySaver, ProcessInfo.processInfo.isLowPowerModeEnabled {
                limit = min(limit, 4)
            }
            WebViewPool.shared.softLimit = limit
        } else {
            WebViewPool.shared.softLimit = 12
        }
    }

    /// Effective data-saver flag (manual toggle, or battery auto when enabled).
    var effectiveDataSaver: Bool {
        guard edition.isPulse else { return false }
        if pulseDataSaver { return true }
        return pulseBatterySaver && ProcessInfo.processInfo.isLowPowerModeEnabled
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
    private let editionKey = "oriel.browserEdition"
    private let pulseWebViewLimitKey = "oriel.pulseWebViewLimit"
    private let pulseAggressiveUnloadKey = "oriel.pulseAggressiveTabUnload"
    private let pulseDataSaverKey = "oriel.pulseDataSaver"
    private let pulseBatterySaverKey = "oriel.pulseBatterySaver"
    private let pulseCornerEnabledKey = "oriel.pulseCornerEnabled"
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
        if let raw = defaults.string(forKey: editionKey),
           let value = BrowserEdition(rawValue: raw) {
            self.edition = value
        } else {
            self.edition = .classic
        }
        let storedLimit = defaults.object(forKey: pulseWebViewLimitKey) as? Int
        self.pulseWebViewLimit = min(16, max(4, storedLimit ?? 8))
        if defaults.object(forKey: pulseAggressiveUnloadKey) == nil {
            self.pulseAggressiveTabUnload = true
        } else {
            self.pulseAggressiveTabUnload = defaults.bool(forKey: pulseAggressiveUnloadKey)
        }
        self.pulseDataSaver = defaults.bool(forKey: pulseDataSaverKey)
        if defaults.object(forKey: pulseBatterySaverKey) == nil {
            self.pulseBatterySaver = true
        } else {
            self.pulseBatterySaver = defaults.bool(forKey: pulseBatterySaverKey)
        }
        if defaults.object(forKey: pulseCornerEnabledKey) == nil {
            self.pulseCornerEnabled = true
        } else {
            self.pulseCornerEnabled = defaults.bool(forKey: pulseCornerEnabledKey)
        }
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
        applyEditionDefaultsIfNeeded(previous: nil)
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
