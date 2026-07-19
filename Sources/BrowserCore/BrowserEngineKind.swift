import Foundation

/// Which page engine Oriel prefers. Apple requires WebKit on iOS/iPadOS.
enum BrowserEngineKind: String, CaseIterable, Identifiable, Codable, Sendable {
    /// macOS: each tab picks WebKit, Chromium Compatible, or Native (Blink) from the page (default).
    case smart
    /// Apple WebKit — only legal browser engine on iPhone/iPad; fixed identity when chosen on Mac.
    case webkit
    /// macOS: WebKit host with Chromium desktop UA + extension-friendly shims.
    case chromiumCompatibility
    /// macOS: real Blink via embedded CEF or managed system Chromium app-windows.
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
            return "Each tab chooses for itself: real Blink (Native) when available for stubborn apps, Chromium Compatible as fallback, WebKit for Apple/captcha-sensitive sites."
        case .webkit:
            return "Apple’s engine for every tab. Required on iPhone and iPad. Best system integration."
        case .chromiumCompatibility:
            return "Every tab uses Chrome desktop identity on WebKit (unless a site override forces WebKit). Not Blink."
        case .chromiumNative:
            return "Real Chromium/Blink: embedded CEF when built in, otherwise managed system Chromium app-windows on Mac."
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
    /// True when Mac can run real Blink for Native (in-tab CEF or managed Chromium app).
    static var canUseNativeBlink: Bool {
        #if os(macOS)
        ChromiumNativeHost.isEmbeddedHostingReady || ChromiumEngineBridge.systemChromiumInstalled
        #else
        false
        #endif
    }

    static var chromiumNativeStatus: ChromiumNativeStatus {
        #if os(iOS)
        return .unavailableOnIOS
        #else
        if canUseNativeBlink || ChromiumNativeHost.isEmbeddedFrameworkAvailable {
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
            return canUseNativeBlink ? .chromiumNative : .chromiumCompatibility
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
        case .forceChromiumCompatible:
            return .chromiumCompatibility
        case .openInSystemChrome:
            // Prefer real Blink hand-off / Native when possible.
            return canUseNativeBlink ? .chromiumNative : .chromiumCompatibility
        case .followDefault:
            break
        }

        switch global {
        case .smart:
            return bestEngine(forHost: host, policy: policy)
        case .webkit:
            if policy.autoChromiumForStubbornSites, ChromiumAutoSiteList.matches(host) {
                return bestChromiumEngine(forHost: host, policy: policy)
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

    /// Smart pick: WebKit vs Compatible vs Native (Blink) for this host.
    static func bestEngine(forHost host: String?, policy: ChromiumSitePolicy) -> BrowserEngineKind {
        #if os(iOS)
        return .webkit
        #else
        // 1) Apple ID / captcha / banking-style trust → WebKit only.
        if ChromiumAutoSiteList.prefersWebKitIdentity(host) {
            return .webkit
        }
        // 2) Stubborn desktop web apps → real Blink when available, else Compatible.
        if ChromiumAutoSiteList.matches(host) {
            return bestChromiumEngine(forHost: host, policy: policy)
        }
        // 3) Start page / ordinary sites → WebKit.
        return .webkit
        #endif
    }

    /// Among Chromium options, prefer Native/Blink when Smart (or auto-list) asks for Chromium.
    static func bestChromiumEngine(forHost host: String?, policy: ChromiumSitePolicy) -> BrowserEngineKind {
        #if os(iOS)
        return .webkit
        #else
        // Sites that often break on WebKit+UA alone → insist on Native when possible.
        if ChromiumAutoSiteList.prefersRealBlink(host), canUseNativeBlink {
            return .chromiumNative
        }
        if policy.smartPrefersNativeBlink, canUseNativeBlink {
            return .chromiumNative
        }
        return .chromiumCompatibility
        #endif
    }

    /// Short reason for UI (Smart chip / Site Passport).
    static func resolveReason(
        global: BrowserEngineKind,
        tabOverride: BrowserEngineKind?,
        host: String?,
        policy: ChromiumSitePolicy,
        concrete: BrowserEngineKind
    ) -> String {
        #if os(iOS)
        return "iPhone and iPad always use WebKit."
        #else
        if let tabOverride {
            return tabOverride == .smart
                ? "This tab follows Smart for \(host ?? "this page")."
                : "This tab is locked to \(concrete.displayName)."
        }
        switch policy.preference(forHost: host) {
        case .forceWebKit:
            return "Site override keeps this host on WebKit."
        case .forceChromiumCompatible:
            return "Site override uses Chromium Compatible (Chrome identity on WebKit — not Blink)."
        case .openInSystemChrome:
            return canUseNativeBlink
                ? "Site preference uses Chromium Native / system Blink."
                : "Site preference asked for system Chrome; falling back to Compatible."
        case .followDefault:
            break
        }
        switch global {
        case .smart:
            if ChromiumAutoSiteList.prefersWebKitIdentity(host) {
                return "Smart → WebKit (Apple / captcha-sensitive host)."
            }
            if ChromiumAutoSiteList.matches(host) {
                if concrete == .chromiumNative {
                    return ChromiumAutoSiteList.prefersRealBlink(host)
                        ? "Smart → Chromium Native / Blink (needs real Chromium)."
                        : "Smart → Chromium Native / Blink (stubborn web app)."
                }
                return "Smart → Chromium Compatible (Native/Blink unavailable — install Chrome or CEF)."
            }
            return "Smart → WebKit for this host."
        case .webkit:
            if concrete != .webkit {
                return "WebKit preferred, but auto-upgraded a stubborn host to \(concrete.displayName)."
            }
            return "Settings: WebKit for every tab."
        case .chromiumCompatibility:
            if concrete == .webkit {
                return "Compatible preferred, but this host stays on WebKit."
            }
            return "Settings: Chromium Compatible (not Blink)."
        case .chromiumNative:
            if concrete == .webkit {
                return "Native preferred, but this host stays on WebKit."
            }
            return concrete == .chromiumNative
                ? "Settings: Chromium Native (Blink)."
                : "Native requested; Compatible until Blink (CEF or system Chromium) is available."
        }
        #endif
    }

    static func shouldHandOffToSystemChromium(host: String?, policy: ChromiumSitePolicy) -> Bool {
        #if os(macOS)
        if policy.preference(forHost: host) == .openInSystemChrome {
            return true
        }
        // Smart/Native without in-tab CEF → managed Chromium window is the Blink surface.
        return false
        #else
        return false
        #endif
    }
}
