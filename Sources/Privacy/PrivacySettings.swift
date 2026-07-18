import Foundation

struct SiteShieldSettings: Codable, Equatable, Sendable {
    var contentBlockingEnabled: Bool = true
    var httpsUpgradeEnabled: Bool = true

    static let `default` = SiteShieldSettings()
}

struct PrivacySettingsSnapshot: Codable, Equatable, Sendable {
    var contentBlockingEnabled: Bool = true
    var httpsUpgradeEnabled: Bool = true
    var blockThirdPartyCookies: Bool = false
    var fingerprintingProtection: Bool = true
    var httpsOnlyMode: Bool = false
    var siteSettings: [String: SiteShieldSettings] = [:]

    enum CodingKeys: String, CodingKey {
        case contentBlockingEnabled, httpsUpgradeEnabled, blockThirdPartyCookies
        case fingerprintingProtection, httpsOnlyMode, siteSettings
    }

    init(
        contentBlockingEnabled: Bool = true,
        httpsUpgradeEnabled: Bool = true,
        blockThirdPartyCookies: Bool = false,
        fingerprintingProtection: Bool = true,
        httpsOnlyMode: Bool = false,
        siteSettings: [String: SiteShieldSettings] = [:]
    ) {
        self.contentBlockingEnabled = contentBlockingEnabled
        self.httpsUpgradeEnabled = httpsUpgradeEnabled
        self.blockThirdPartyCookies = blockThirdPartyCookies
        self.fingerprintingProtection = fingerprintingProtection
        self.httpsOnlyMode = httpsOnlyMode
        self.siteSettings = siteSettings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        contentBlockingEnabled = try c.decodeIfPresent(Bool.self, forKey: .contentBlockingEnabled) ?? true
        httpsUpgradeEnabled = try c.decodeIfPresent(Bool.self, forKey: .httpsUpgradeEnabled) ?? true
        blockThirdPartyCookies = try c.decodeIfPresent(Bool.self, forKey: .blockThirdPartyCookies) ?? false
        fingerprintingProtection = try c.decodeIfPresent(Bool.self, forKey: .fingerprintingProtection) ?? true
        httpsOnlyMode = try c.decodeIfPresent(Bool.self, forKey: .httpsOnlyMode) ?? false
        siteSettings = try c.decodeIfPresent([String: SiteShieldSettings].self, forKey: .siteSettings) ?? [:]
    }
}

@MainActor
@Observable
final class PrivacySettings {
    var contentBlockingEnabled: Bool {
        didSet { persist() }
    }

    var httpsUpgradeEnabled: Bool {
        didSet { persist() }
    }

    /// When enabled, Oriel attaches a WebKit `block-cookies` rule for third-party loads.
    var blockThirdPartyCookies: Bool {
        didSet { persist() }
    }

    /// Spoof canvas / audio / WebGL / hardware signals (best-effort).
    var fingerprintingProtection: Bool {
        didSet { persist() }
    }

    /// Block plain HTTP navigations that cannot be upgraded (localhost exempt).
    var httpsOnlyMode: Bool {
        didSet { persist() }
    }

    private(set) var siteSettings: [String: SiteShieldSettings]
    private let fileName = "privacy-settings.json"

    init() {
        if let loaded = try? JSONFileStore.load(PrivacySettingsSnapshot.self, from: fileName) {
            contentBlockingEnabled = loaded.contentBlockingEnabled
            httpsUpgradeEnabled = loaded.httpsUpgradeEnabled
            blockThirdPartyCookies = loaded.blockThirdPartyCookies
            fingerprintingProtection = loaded.fingerprintingProtection
            httpsOnlyMode = loaded.httpsOnlyMode
            siteSettings = loaded.siteSettings
        } else {
            contentBlockingEnabled = true
            httpsUpgradeEnabled = true
            // Off by default so Google Account and similar OAuth popups can keep session cookies.
            blockThirdPartyCookies = false
            fingerprintingProtection = true
            httpsOnlyMode = false
            siteSettings = [:]
        }
    }

    func settings(forHost host: String?) -> SiteShieldSettings {
        guard let host, !host.isEmpty else { return .default }
        return siteSettings[host.lowercased()] ?? .default
    }

    func setContentBlocking(_ enabled: Bool, forHost host: String?) {
        guard let key = normalizedHost(host) else { return }
        var current = siteSettings[key] ?? .default
        current.contentBlockingEnabled = enabled
        siteSettings[key] = current
        persist()
    }

    func setHTTPSUpgrade(_ enabled: Bool, forHost host: String?) {
        guard let key = normalizedHost(host) else { return }
        var current = siteSettings[key] ?? .default
        current.httpsUpgradeEnabled = enabled
        siteSettings[key] = current
        persist()
    }

    func effectiveContentBlocking(forHost host: String?) -> Bool {
        contentBlockingEnabled && settings(forHost: host).contentBlockingEnabled
    }

    func effectiveHTTPSUpgrade(forHost host: String?) -> Bool {
        httpsUpgradeEnabled && settings(forHost: host).httpsUpgradeEnabled
    }

    private func normalizedHost(_ host: String?) -> String? {
        guard let host else { return nil }
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }

    private func persist() {
        let snapshot = PrivacySettingsSnapshot(
            contentBlockingEnabled: contentBlockingEnabled,
            httpsUpgradeEnabled: httpsUpgradeEnabled,
            blockThirdPartyCookies: blockThirdPartyCookies,
            fingerprintingProtection: fingerprintingProtection,
            httpsOnlyMode: httpsOnlyMode,
            siteSettings: siteSettings
        )
        try? JSONFileStore.save(snapshot, to: fileName)
    }
}
