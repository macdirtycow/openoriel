import Foundation

/// Which page engine Oriel prefers. Apple requires WebKit on iOS/iPadOS.
enum BrowserEngineKind: String, CaseIterable, Identifiable, Codable, Sendable {
    /// macOS: each tab picks WebKit or Chromium Compatible from the page (default).
    case smart
    /// Apple WebKit — only legal browser engine on iPhone/iPad; fixed identity when chosen on Mac.
    case webkit
    /// macOS: WebKit host with Chromium desktop UA + extension-friendly shims.
    case chromiumCompatibility
    /// macOS: reserved for a future linked Chromium/CEF binary (not bundled yet).
    case chromiumNative

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smart: "Smart (best per tab)"
        case .webkit: "WebKit"
        case .chromiumCompatibility: "Chromium Compatible"
        case .chromiumNative: "Chromium Native"
        }
    }

    var subtitle: String {
        switch self {
        case .smart:
            return "Each tab chooses for itself: Chromium Compatible for Meet/Teams/Discord-style apps, WebKit for everything else (and Apple/captcha-sensitive sites)."
        case .webkit:
            return "Apple’s engine for every tab. Required on iPhone and iPad. Best system integration."
        case .chromiumCompatibility:
            return "Every tab uses Chrome desktop identity on WebKit (unless a site override forces WebKit)."
        case .chromiumNative:
            return "Real Chromium: embedded CEF when installed, otherwise managed system Chromium app-windows on Mac."
        }
    }

    var systemImage: String {
        switch self {
        case .smart: "sparkles"
        case .webkit: "apple.logo"
        case .chromiumCompatibility: "globe.badge.chevron.backward"
        case .chromiumNative: "cpu"
        }
    }

    /// Engines the current platform may offer in Settings.
    static var availableOnThisPlatform: [BrowserEngineKind] {
        #if os(iOS)
        return [.webkit]
        #else
        return [.smart, .webkit, .chromiumCompatibility, .chromiumNative]
        #endif
    }

    var isSelectableOnThisPlatform: Bool {
        Self.availableOnThisPlatform.contains(self)
    }

    /// Concrete engines that can actually paint/identity a page (not the Smart chooser).
    var isConcrete: Bool {
        switch self {
        case .smart: false
        case .webkit, .chromiumCompatibility, .chromiumNative: true
        }
    }
}

enum ChromiumNativeStatus: Sendable {
    case unavailableOnIOS
    case frameworkNotLinked
    case available

    var userMessage: String {
        switch self {
        case .unavailableOnIOS:
            return "Apple requires all iPhone and iPad browsers to use WebKit. Chromium cannot render pages here."
        case .frameworkNotLinked:
            return "Embedded CEF is not linked in this binary yet. On Mac: run Scripts/fetch-cef-macos.sh and Scripts/enable-cef-macos.sh, then rebuild. Until then, Native mode opens a managed Chromium app-window (real Blink). Or use Chromium Compatible for WebKit + Chrome identity."
        case .available:
            return "Chromium Native framework is available — rebuild with ORIEL_HAS_CEF for in-tab Blink, or use managed windows."
        }
    }
}

/// Policy helpers for dual-engine Oriel (WebKit + optional Chromium path on Mac).
/// Always evaluated on the main actor — site policy and native host probes are `@MainActor`.
@MainActor
enum RenderingEnginePolicy {
    static var chromiumNativeStatus: ChromiumNativeStatus {
        #if os(iOS)
        return .unavailableOnIOS
        #else
        if ChromiumNativeHost.isEmbeddedFrameworkAvailable {
            return .available
        }
        return .frameworkNotLinked
        #endif
    }

    /// Resolve a stored preference to something this binary can actually run (no host context).
    /// Smart without a host falls back to WebKit.
    static func resolved(_ preferred: BrowserEngineKind) -> BrowserEngineKind {
        #if os(iOS)
        return .webkit
        #else
        switch preferred {
        case .smart, .webkit:
            return .webkit
        case .chromiumCompatibility:
            return .chromiumCompatibility
        case .chromiumNative:
            return chromiumNativeStatus == .available ? .chromiumNative : .chromiumCompatibility
        }
        #endif
    }

    static func usesChromeDesktopUserAgent(_ kind: BrowserEngineKind) -> Bool {
        switch resolved(kind) {
        case .smart, .webkit: return false
        case .chromiumCompatibility, .chromiumNative: return true
        }
    }

    /// Resolve the effective **concrete** engine for one tab’s destination host.
    /// Priority: tab override → host preference → Smart / auto list → global Settings.
    static func resolve(
        global: BrowserEngineKind,
        tabOverride: BrowserEngineKind?,
        host: String?,
        policy: ChromiumSitePolicy
    ) -> BrowserEngineKind {
        #if os(iOS)
        return .webkit
        #else
        if let tabOverride {
            let locked = tabOverride == .smart ? bestEngine(forHost: host, policy: policy) : resolved(tabOverride)
            return locked
        }

        switch policy.preference(forHost: host) {
        case .forceWebKit:
            return .webkit
        case .forceChromiumCompatible, .openInSystemChrome:
            return .chromiumCompatibility
        case .followDefault:
            break
        }

        switch global {
        case .smart:
            return bestEngine(forHost: host, policy: policy)
        case .webkit:
            if policy.autoChromiumForStubbornSites, ChromiumAutoSiteList.matches(host) {
                return .chromiumCompatibility
            }
            return .webkit
        case .chromiumCompatibility:
            // Even “always Compatible” keeps Apple/captcha-sensitive hosts on WebKit.
            if ChromiumAutoSiteList.prefersWebKitIdentity(host) {
                return .webkit
            }
            return .chromiumCompatibility
        case .chromiumNative:
            if ChromiumAutoSiteList.prefersWebKitIdentity(host) {
                return .webkit
            }
            return resolved(.chromiumNative)
        }
        #endif
    }

    /// Pick WebKit vs Chromium Compatible for this host (Smart mode).
    static func bestEngine(forHost host: String?, policy: ChromiumSitePolicy) -> BrowserEngineKind {
        #if os(iOS)
        return .webkit
        #else
        if ChromiumAutoSiteList.prefersWebKitIdentity(host) {
            return .webkit
        }
        if ChromiumAutoSiteList.matches(host) {
            return .chromiumCompatibility
        }
        // Start page / empty host → WebKit.
        return .webkit
        #endif
    }

    static func shouldHandOffToSystemChromium(host: String?, policy: ChromiumSitePolicy) -> Bool {
        #if os(macOS)
        return policy.preference(forHost: host) == .openInSystemChrome
        #else
        return false
        #endif
    }
}
