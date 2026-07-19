import Foundation

/// User-Agent selection. Prefer WebKit’s native Safari UA so sites (Google, Cloudflare)
/// don’t treat Oriel as a spoofed Chrome browser and trigger bot checks.
///
/// Exceptions (store hosts only):
/// - Chrome Web Store → desktop Chrome UA (avoids “not compatible with a phone”)
/// - Firefox Add-ons → desktop Firefox UA (avoids “You’ll need Firefox…”)
enum UserAgentPolicy {
    /// Chrome desktop UA — CRX downloads and Chrome Web Store page browsing only.
    static let chromeDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Firefox desktop UA — AMO page browsing only (install API fetches use a separate Oriel UA).
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

    /// Narrow host check — do not use for all of Google Search (bot checks).
    static func isChromeWebStoreHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "chromewebstore.google.com"
            || host == "chrome.google.com"
            || host.hasSuffix(".chrome.google.com")
    }

    static func isFirefoxAddonsHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return host == "addons.mozilla.org"
            || host == "addons-dev.allizom.org"
            || host.hasSuffix(".addons.mozilla.org")
    }

    /// Extension / theme store hosts that need a desktop browser UA on iPhone/iPad.
    static func isExtensionStoreHost(_ host: String?) -> Bool {
        isChromeWebStoreHost(host) || isFirefoxAddonsHost(host)
    }

    /// `nil` means “use WebKit’s default Safari UA”.
    static func customUserAgent(for url: URL?, requestsDesktopSite: Bool) -> String? {
        let host = url?.host
        if isChromeWebStoreHost(host) {
            return chromeDesktop
        }
        if isFirefoxAddonsHost(host) {
            return firefoxDesktop
        }
        if requestsDesktopSite {
            return safariDesktop
        }
        return nil
    }
}
