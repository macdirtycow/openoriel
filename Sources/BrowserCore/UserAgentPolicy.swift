import Foundation

/// User-Agent selection. Prefer WebKit’s native Safari UA so sites (Google, Cloudflare)
/// don’t treat Oriel as a spoofed Chrome browser and trigger bot checks.
///
/// Chrome Web Store / Firefox AMO **page browsing** no longer forces a desktop UA —
/// use the native **Oriel Store** for catalogs. `chromeDesktop` remains for CRX downloads
/// and Oriel Store’s own Chrome catalog fetch.
enum UserAgentPolicy {
    /// Chrome desktop UA — CRX downloads + Oriel Store Chrome catalog fetch only.
    static let chromeDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Firefox desktop UA — reserved; AMO website install spoof is JS-side if the user keeps browsing.
    static let firefoxDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:133.0) Gecko/20100101 Firefox/133.0"

    static let safariDesktop = BrowserConstants.desktopUserAgent

    static func isGoogleHost(_ host: String?) -> Bool {
        guard var host = host?.lowercased(), !host.isEmpty else { return false }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        if host == "google.com" || host.hasSuffix(".google.com") {
            return true
        }
        if host.hasPrefix("google.") {
            return true
        }
        return false
    }

    /// Host-only helper (tests / simple checks). Prefer ``isChromeWebStoreURL(_:)`` for policy.
    static func isChromeWebStoreHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "chromewebstore.google.com"
            || host == "chrome.google.com"
            || host.hasSuffix(".chrome.google.com")
    }

    /// Narrow: only real Web Store URLs — not every `chrome.google.com` page.
    static func isChromeWebStoreURL(_ url: URL?) -> Bool {
        guard let url, let host = url.host?.lowercased(), !host.isEmpty else { return false }
        if host == "chromewebstore.google.com" { return true }
        if host == "chrome.google.com" || host.hasSuffix(".chrome.google.com") {
            let path = url.path.lowercased()
            return path.contains("webstore") || path.contains("/web-store")
        }
        return false
    }

    static func isFirefoxAddonsHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "addons.mozilla.org"
            || host == "addons-dev.allizom.org"
            || host.hasSuffix(".addons.mozilla.org")
    }

    static func isFirefoxAddonsURL(_ url: URL?) -> Bool {
        isFirefoxAddonsHost(url?.host)
    }

    /// Chrome Web Store / Firefox Add-ons website URLs (tip → Oriel Store).
    static func isExtensionStoreURL(_ url: URL?) -> Bool {
        isChromeWebStoreURL(url) || isFirefoxAddonsURL(url)
    }

    /// Host convenience used by older call sites — prefers being conservative.
    static func isExtensionStoreHost(_ host: String?) -> Bool {
        guard let host else { return false }
        if host == "chromewebstore.google.com" { return true }
        return isFirefoxAddonsHost(host)
    }

    /// `nil` means “use WebKit’s default Safari UA”.
    /// Never auto-desktop store websites — Oriel Store is the catalog UI.
    /// Only an explicit Request Desktop Website changes the UA.
    static func customUserAgent(
        for url: URL?,
        requestsDesktopSite: Bool,
        preferredEngine: BrowserEngineKind = .webkit
    ) -> String? {
        if RenderingEnginePolicy.usesChromeDesktopUserAgent(preferredEngine) {
            return chromeDesktop
        }
        if requestsDesktopSite {
            return safariDesktop
        }
        return nil
    }
}
