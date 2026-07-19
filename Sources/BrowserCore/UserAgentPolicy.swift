import Foundation

/// User-Agent selection. Prefer WebKit’s native Safari UA so sites (Google, Cloudflare)
/// don’t treat Oriel as a spoofed Chrome browser and trigger bot checks.
///
/// Exception: Chrome Web Store pages need a desktop Chrome UA on iPhone/iPad, otherwise
/// the store serves “not compatible with a phone” and blocks the install UI.
enum UserAgentPolicy {
    /// Chrome desktop UA — CRX downloads and Chrome Web Store page browsing only.
    static let chromeDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

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

    /// `nil` means “use WebKit’s default Safari UA”.
    static func customUserAgent(for url: URL?, requestsDesktopSite: Bool) -> String? {
        // CWS must look like desktop Chrome or it shows phone-incompatibility UI.
        if isChromeWebStoreHost(url?.host) {
            return chromeDesktop
        }
        if requestsDesktopSite {
            return safariDesktop
        }
        return nil
    }
}
