import Foundation

/// User-Agent selection. Google serves a different (often older-looking) UI to Safari/WebKit
/// than to Chromium browsers like Brave — so Google hosts get a Chrome-like UA.
enum UserAgentPolicy {
    /// Current-ish Chrome on macOS (matches what Brave/Chrome advertise).
    static let chromeDesktop =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

    /// Chrome on Android — Google’s modern mobile Search UI (closer to Brave Android than Mobile Safari).
    static let chromeMobile =
        "Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36"

    static let safariDesktop = BrowserConstants.desktopUserAgent

    static func isGoogleHost(_ host: String?) -> Bool {
        guard var host = host?.lowercased(), !host.isEmpty else { return false }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        if host == "google.com" || host.hasSuffix(".google.com") {
            return true
        }
        // Country TLDs: google.nl, google.co.uk, google.com.au, …
        if host.hasPrefix("google.") {
            return true
        }
        return false
    }

    /// `nil` means “use WebKit’s default Safari UA”.
    static func customUserAgent(for url: URL?, requestsDesktopSite: Bool) -> String? {
        if isGoogleHost(url?.host) {
            #if os(macOS)
            return chromeDesktop
            #else
            return requestsDesktopSite ? chromeDesktop : chromeMobile
            #endif
        }
        if requestsDesktopSite {
            return safariDesktop
        }
        return nil
    }
}
