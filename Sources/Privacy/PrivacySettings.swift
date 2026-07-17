import Foundation

struct SiteShieldSettings: Codable, Equatable, Sendable {
    var contentBlockingEnabled: Bool = true
    var httpsUpgradeEnabled: Bool = true

    static let `default` = SiteShieldSettings()
}

struct PrivacySettingsSnapshot: Codable, Equatable, Sendable {
    var contentBlockingEnabled: Bool = true
    var httpsUpgradeEnabled: Bool = true
    var blockThirdPartyCookies: Bool = true
    var siteSettings: [String: SiteShieldSettings] = [:]
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

    /// Documented limitation: WebKit cookie policy varies by OS; we apply best-effort configuration.
    var blockThirdPartyCookies: Bool {
        didSet { persist() }
    }

    private(set) var siteSettings: [String: SiteShieldSettings]
    private let fileName = "privacy-settings.json"

    init() {
        if let loaded = try? JSONFileStore.load(PrivacySettingsSnapshot.self, from: fileName) {
            contentBlockingEnabled = loaded.contentBlockingEnabled
            httpsUpgradeEnabled = loaded.httpsUpgradeEnabled
            blockThirdPartyCookies = loaded.blockThirdPartyCookies
            siteSettings = loaded.siteSettings
        } else {
            contentBlockingEnabled = true
            httpsUpgradeEnabled = true
            blockThirdPartyCookies = true
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
            siteSettings: siteSettings
        )
        try? JSONFileStore.save(snapshot, to: fileName)
    }
}
