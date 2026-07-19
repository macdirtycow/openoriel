import Foundation

/// How well an extension is expected to run under Oriel’s WebKit host.
enum ExtensionCompatLevel: String, Hashable, Sendable, CaseIterable {
    case full
    case partial
    case unsupported

    var title: String {
        switch self {
        case .full: return "Fully supported"
        case .partial: return "Partial support"
        case .unsupported: return "Not supported"
        }
    }

    var accessibilityLabel: String { "Oriel compatibility: \(title)" }
}

/// Oriel-specific compatibility score (estimated community + local installs).
struct OrielCompatScore: Hashable, Sendable {
    /// 0…100 WebKit fit estimate.
    var percent: Int
    /// Derived 0…5 for star display.
    var stars: Double { Double(percent) / 20.0 }
    /// Seeded community installs (until a real backend exists).
    var communityInstalls: Int
    /// Optional “works as expected” share (seeded).
    var worksAsExpectedPercent: Int?
    /// Installs recorded on this device.
    var localInstalls: Int
    /// True when community numbers are estimates, not live telemetry.
    var isEstimated: Bool
}

struct ExtensionCompatReport: Hashable, Sendable {
    var level: ExtensionCompatLevel
    var blockedAPIs: [String]
    var limitedAPIs: [String]
    var score: OrielCompatScore

    var shouldWarnBeforeInstall: Bool {
        level == .partial || level == .unsupported
    }

    var installWarning: String {
        if level == .unsupported {
            return "This extension is unlikely to work in Oriel because it requires APIs that are unavailable on WebKit (\(blockedSummary))."
        }
        if blockedAPIs.isEmpty && limitedAPIs.isEmpty {
            return "This extension may have limited functionality on WebKit."
        }
        let apis = (blockedAPIs + limitedAPIs).prefix(6).joined(separator: ", ")
        return "This extension may have limited functionality because it requires APIs that are unavailable on WebKit (\(apis))."
    }

    private var blockedSummary: String {
        let list = blockedAPIs.isEmpty ? limitedAPIs : blockedAPIs
        return list.prefix(5).joined(separator: ", ")
    }
}

/// Assesses store listings against WebKit / Oriel capabilities.
enum ExtensionCompatibility {
    /// Permissions that Oriel strips or cannot host — hard blockers.
    static let blockedPermissions: Set<String> = [
        "debugger",
        "proxy",
        "nativeMessaging",
        "enterprise.deviceAttributes",
        "enterprise.hardwarePlatform",
        "enterprise.platformKeys",
        "privacy",
        "fontSettings",
        "gcm",
        "system.cpu",
        "system.memory",
        "system.storage",
        "system.display",
        "loginState",
        "dns"
    ]

    /// Permissions that often degrade features but may still load.
    static let limitedPermissions: Set<String> = [
        "webRequestBlocking",
        "webRequestFilterResponse",
        "webRequestAuthProvider",
        "declarativeNetRequestFeedback",
        "tabCapture",
        "tabHide",
        "userScripts",
        "search",
        "sessions",
        "browsingData",
        "cookies",
        "history",
        "downloads",
        "downloads.open",
        "clipboardRead",
        "clipboardWrite",
        "notifications",
        "geolocation",
        "identity",
        "management"
    ]

    static func assess(_ listing: UnifiedStoreListing) -> ExtensionCompatReport {
        if listing.kind == .theme {
            return report(
                level: .full,
                blocked: [],
                limited: [],
                listing: listing,
                basePercent: 96
            )
        }

        if let override = knownOverride(for: listing.id) {
            return report(
                level: override.level,
                blocked: override.blocked,
                limited: override.limited,
                listing: listing,
                basePercent: override.percent,
                community: override.community,
                works: override.works
            )
        }

        let permissions = listing.offers.flatMap(\.permissions)
        let blocked = permissions.filter { blockedPermissions.contains($0) }.sorted()
        let limited = permissions.filter { limitedPermissions.contains($0) }.sorted()

        let level: ExtensionCompatLevel
        let base: Int
        if !blocked.isEmpty {
            // Multiple hard APIs → unsupported; one may still be partial if the rest is mild.
            level = blocked.count >= 2 || blocked.contains("debugger") || blocked.contains("proxy") || blocked.contains("nativeMessaging")
                ? (blocked.contains("debugger") || blocked.contains("proxy") ? .unsupported : .partial)
                : .partial
            base = level == .unsupported ? 18 : max(35, 70 - blocked.count * 12 - limited.count * 3)
        } else if limited.count >= 4 {
            level = .partial
            base = max(45, 78 - limited.count * 4)
        } else if !limited.isEmpty {
            level = .partial
            base = max(62, 88 - limited.count * 5)
        } else if permissions.isEmpty {
            // Chrome-only rows often lack permission metadata — optimistic partial/unknown → treat as partial-leaning full.
            level = .partial
            base = 72
        } else {
            level = .full
            base = 94
        }

        // Prefer “unsupported” when nativeMessaging/debugger/proxy dominate.
        let forcedUnsupported = blocked.contains("debugger")
            || blocked.contains("proxy")
            || (blocked.contains("nativeMessaging") && limited.count >= 2)
        let finalLevel = forcedUnsupported ? .unsupported : level
        let finalBase = forcedUnsupported ? min(base, 22) : base

        return report(
            level: finalLevel,
            blocked: Array(Set(blocked)).sorted(),
            limited: Array(Set(limited)).sorted(),
            listing: listing,
            basePercent: finalBase
        )
    }

    static func recordLocalInstall(listingID: String) {
        let key = defaultsKey(listingID)
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }

    static func localInstallCount(listingID: String) -> Int {
        UserDefaults.standard.integer(forKey: defaultsKey(listingID))
    }

    // MARK: - Private

    private static func defaultsKey(_ listingID: String) -> String {
        "oriel.compat.installs.\(listingID)"
    }

    private static func report(
        level: ExtensionCompatLevel,
        blocked: [String],
        limited: [String],
        listing: UnifiedStoreListing,
        basePercent: Int,
        community: Int? = nil,
        works: Int? = nil
    ) -> ExtensionCompatReport {
        let seed = communitySeed(for: listing.id)
        let local = localInstallCount(listingID: listing.id)
        let percent = min(100, max(0, basePercent))
        let score = OrielCompatScore(
            percent: percent,
            communityInstalls: community ?? seed.installs,
            worksAsExpectedPercent: works ?? seed.works,
            localInstalls: local,
            isEstimated: true
        )
        return ExtensionCompatReport(
            level: level,
            blockedAPIs: blocked,
            limitedAPIs: limited,
            score: score
        )
    }

    private struct Override {
        var level: ExtensionCompatLevel
        var blocked: [String]
        var limited: [String]
        var percent: Int
        var community: Int
        var works: Int
    }

    /// Hand-tuned rows for popular extensions so badges stay honest and stable.
    private static func knownOverride(for listingID: String) -> Override? {
        switch listingID {
        case "darkreader":
            return Override(level: .full, blocked: [], limited: [], percent: 96, community: 428, works: 97)
        case "ublockorigin":
            return Override(
                level: .partial,
                blocked: ["privacy", "dns"],
                limited: ["webRequestBlocking"],
                percent: 74,
                community: 891,
                works: 81
            )
        case "ublockoriginlite":
            return Override(level: .full, blocked: [], limited: ["declarativeNetRequestFeedback"], percent: 91, community: 312, works: 93)
        case "bitwarden":
            return Override(
                level: .partial,
                blocked: [],
                limited: ["clipboardRead", "clipboardWrite", "notifications"],
                percent: 86,
                community: 654,
                works: 90
            )
        case "sponsorblock":
            return Override(level: .full, blocked: [], limited: [], percent: 94, community: 501, works: 95)
        case "privacybadger":
            return Override(
                level: .partial,
                blocked: [],
                limited: ["webRequestBlocking", "tabs"],
                percent: 70,
                community: 220,
                works: 78
            )
        case "duckducgoprivacy", "duckducgoprivacyessentials":
            return Override(level: .partial, blocked: [], limited: ["tabs", "webRequest"], percent: 80, community: 188, works: 84)
        default:
            return nil
        }
    }

    private static func communitySeed(for listingID: String) -> (installs: Int, works: Int?) {
        // Stable pseudo-seed from id so unknown extensions still show Oriel numbers.
        var hash: UInt64 = 5381
        for scalar in listingID.unicodeScalars {
            hash = ((hash << 5) &+ hash) &+ UInt64(scalar.value)
        }
        let installs = Int(120 + (hash % 480))
        let works = Int(72 + (hash % 24))
        return (installs, works)
    }
}
