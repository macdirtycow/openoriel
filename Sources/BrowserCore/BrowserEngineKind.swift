import Foundation

/// Which page engine Oriel prefers. Apple requires WebKit on iOS/iPadOS.
enum BrowserEngineKind: String, CaseIterable, Identifiable, Codable, Sendable {
    /// Apple WebKit — only legal browser engine on iPhone/iPad, default everywhere.
    case webkit
    /// macOS: WebKit host with Chromium desktop UA + extension-friendly shims.
    case chromiumCompatibility
    /// macOS: reserved for a future linked Chromium/CEF binary (not bundled yet).
    case chromiumNative

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webkit: "WebKit"
        case .chromiumCompatibility: "Chromium Compatible"
        case .chromiumNative: "Chromium Native"
        }
    }

    var subtitle: String {
        switch self {
        case .webkit:
            return "Apple’s engine. Required on iPhone and iPad. Best system integration."
        case .chromiumCompatibility:
            return "Still WebKit under the hood, with Chrome desktop identity for tougher sites and extensions."
        case .chromiumNative:
            return "Real Chromium/CEF when linked into the Mac build. Not available in this binary yet."
        }
    }

    var systemImage: String {
        switch self {
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
        return [.webkit, .chromiumCompatibility, .chromiumNative]
        #endif
    }

    var isSelectableOnThisPlatform: Bool {
        Self.availableOnThisPlatform.contains(self)
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
            return "This Mac build does not include a Chromium/CEF framework yet. Use Chromium Compatible for Chrome identity on WebKit, or open a page in system Chrome."
        case .available:
            return "Chromium Native is linked and can host tabs."
        }
    }
}

/// Policy helpers for dual-engine Oriel (WebKit + optional Chromium path on Mac).
enum RenderingEnginePolicy {
    static var chromiumNativeStatus: ChromiumNativeStatus {
        #if os(iOS)
        return .unavailableOnIOS
        #else
        // Real CEF would set a compile flag / Bundle check. Until then: not linked.
        if Bundle.main.path(forResource: "Chromium Embedded Framework", ofType: "framework") != nil
            || Bundle.main.path(forResource: "OrielChromium", ofType: "framework") != nil {
            return .available
        }
        return .frameworkNotLinked
        #endif
    }

    /// Resolve a stored preference to something this binary can actually run.
    static func resolved(_ preferred: BrowserEngineKind) -> BrowserEngineKind {
        #if os(iOS)
        return .webkit
        #else
        switch preferred {
        case .webkit:
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
        case .webkit: return false
        case .chromiumCompatibility, .chromiumNative: return true
        }
    }
}
