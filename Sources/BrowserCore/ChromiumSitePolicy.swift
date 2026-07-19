import Foundation

/// Per-host Chromium preference on Mac (Classic and Pulse).
enum ChromiumHostPreference: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Use the global Settings page-engine choice (and auto-list if enabled).
    case followDefault
    /// Force Safari/WebKit identity for this host.
    case forceWebKit
    /// Force Chromium Compatible identity (Chrome UA + client hints).
    case forceChromiumCompatible
    /// Hand the navigation off to installed Chrome/Chromium/Arc.
    case openInSystemChrome

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .followDefault: "Default"
        case .forceWebKit: "WebKit"
        case .forceChromiumCompatible: "Chromium Compatible"
        case .openInSystemChrome: "Open in system Chrome"
        }
    }
}

/// Seeded hosts that often expect a Chromium desktop client on Mac.
enum ChromiumAutoSiteList {
    /// Suffix-matched (host == entry or host.hasSuffix("." + entry)).
    static let stubbornDesktopHosts: [String] = [
        "meet.google.com",
        "teams.microsoft.com",
        "teams.live.com",
        "web.whatsapp.com",
        "discord.com",
        "web.telegram.org",
        "notion.so",
        "figma.com",
        "spotify.com",
        "open.spotify.com",
        "chatgpt.com",
        "claude.ai",
        "gemini.google.com",
        "drive.google.com",
        "docs.google.com",
        "sheets.google.com",
        "slides.google.com",
        "outlook.office.com",
        "outlook.live.com",
        "web.skype.com",
        "app.slack.com",
        "linear.app",
        "vercel.com",
        "github.dev",
        "vscode.dev",
        "chromewebstore.google.com",
        "classroom.google.com",
        "calendar.google.com",
        "mail.google.com",
        "netflix.com",
        "disneyplus.com",
        "www.disneyplus.com",
        "twitch.tv",
        "www.twitch.tv",
        "xbox.com",
        "www.xbox.com",
        "play.geforcenow.com",
        "stadia.google.com"
    ]

    /// Prefer Safari/WebKit identity (captcha, Apple ID, banking-style trust).
    static let webkitPreferredHosts: [String] = [
        "apple.com",
        "icloud.com",
        "appleid.apple.com",
        "idmsa.apple.com",
        "account.apple.com",
        "icloud.com.cn",
        "accounts.google.com",
        "myaccount.google.com",
        "challenges.cloudflare.com",
        "paypal.com",
        "login.microsoftonline.com"
    ]

    /// Stubborn hosts that often need real Blink (Compatible UA alone is not enough).
    static let realBlinkPreferredHosts: [String] = [
        "netflix.com",
        "disneyplus.com",
        "www.disneyplus.com",
        "discord.com",
        "web.whatsapp.com",
        "meet.google.com",
        "teams.microsoft.com",
        "teams.live.com",
        "play.geforcenow.com",
        "twitch.tv",
        "www.twitch.tv",
        "spotify.com",
        "open.spotify.com"
    ]

    static func matches(_ host: String?) -> Bool {
        matches(host, in: stubbornDesktopHosts)
    }

    static func prefersWebKitIdentity(_ host: String?) -> Bool {
        matches(host, in: webkitPreferredHosts)
    }

    static func prefersRealBlink(_ host: String?) -> Bool {
        matches(host, in: realBlinkPreferredHosts)
    }

    private static func matches(_ host: String?, in list: [String]) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        for entry in list {
            if host == entry || host.hasSuffix("." + entry) {
                return true
            }
        }
        return false
    }
}

private struct ChromiumSitePolicySnapshot: Codable, Equatable, Sendable {
    var autoChromiumForStubbornSites: Bool
    var injectChromeIdentity: Bool
    var suggestSystemChromeForStubbornSites: Bool
    var smartPrefersNativeBlink: Bool?
    var hostPreferences: [String: String]
}

/// Mac dual-engine site policy — per-host overrides + auto Chromium Compatible list.
@MainActor
@Observable
final class ChromiumSitePolicy {
    /// When global engine is WebKit, auto-upgrade stubborn hosts toward Chromium (Native/Compatible).
    var autoChromiumForStubbornSites: Bool {
        didSet { persist() }
    }

    /// Inject `navigator.userAgentData` / Chrome navigator fields when Compatible is active.
    var injectChromeIdentity: Bool {
        didSet { persist() }
    }

    /// Surface “Open in system Chrome” for stubborn sites (does not auto-handoff).
    var suggestSystemChromeForStubbornSites: Bool {
        didSet { persist() }
    }

    /// Smart mode: prefer real Blink (Native) for stubborn hosts when CEF or system Chromium exists.
    var smartPrefersNativeBlink: Bool {
        didSet { persist() }
    }

    private(set) var hostPreferences: [String: ChromiumHostPreference]
    private let fileName = "chromium-site-policy.json"

    init() {
        #if os(macOS)
        if let loaded = try? JSONFileStore.load(ChromiumSitePolicySnapshot.self, from: fileName) {
            autoChromiumForStubbornSites = loaded.autoChromiumForStubbornSites
            injectChromeIdentity = loaded.injectChromeIdentity
            suggestSystemChromeForStubbornSites = loaded.suggestSystemChromeForStubbornSites
            smartPrefersNativeBlink = loaded.smartPrefersNativeBlink ?? true
            var map: [String: ChromiumHostPreference] = [:]
            for (host, raw) in loaded.hostPreferences {
                if let pref = ChromiumHostPreference(rawValue: raw) {
                    map[host] = pref
                }
            }
            hostPreferences = map
        } else {
            autoChromiumForStubbornSites = true
            injectChromeIdentity = true
            suggestSystemChromeForStubbornSites = true
            smartPrefersNativeBlink = true
            hostPreferences = [:]
            persist()
        }
        #else
        autoChromiumForStubbornSites = false
        injectChromeIdentity = false
        suggestSystemChromeForStubbornSites = false
        smartPrefersNativeBlink = false
        hostPreferences = [:]
        #endif
    }

    func preference(forHost host: String?) -> ChromiumHostPreference {
        guard let key = normalizedHost(host) else { return .followDefault }
        return hostPreferences[key] ?? .followDefault
    }

    func setPreference(_ preference: ChromiumHostPreference, forHost host: String?) {
        guard let key = normalizedHost(host) else { return }
        if preference == .followDefault {
            hostPreferences.removeValue(forKey: key)
        } else {
            hostPreferences[key] = preference
        }
        persist()
    }

    func clearAllHostPreferences() {
        hostPreferences = [:]
        persist()
    }

    var sortedHostOverrides: [(host: String, preference: ChromiumHostPreference)] {
        hostPreferences
            .map { (host: $0.key, preference: $0.value) }
            .sorted { $0.host < $1.host }
    }

    private func normalizedHost(_ host: String?) -> String? {
        guard let host, !host.isEmpty else { return nil }
        return host.lowercased()
    }

    private func persist() {
        #if os(macOS)
        let encoded = Dictionary(uniqueKeysWithValues: hostPreferences.map { ($0.key, $0.value.rawValue) })
        let snap = ChromiumSitePolicySnapshot(
            autoChromiumForStubbornSites: autoChromiumForStubbornSites,
            injectChromeIdentity: injectChromeIdentity,
            suggestSystemChromeForStubbornSites: suggestSystemChromeForStubbornSites,
            smartPrefersNativeBlink: smartPrefersNativeBlink,
            hostPreferences: encoded
        )
        try? JSONFileStore.save(snap, to: fileName)
        #endif
    }
}
