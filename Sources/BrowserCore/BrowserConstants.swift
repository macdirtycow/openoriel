import Foundation

enum BrowserConstants {
    static let productName = "Oriel"
    /// Official product domain (openoriel.com).
    static let productWebsiteHost = "openoriel.com"
    static let productWebsiteURL = URL(string: "https://openoriel.com")!

    /// Company that builds Oriel.
    static let publisherName = "inveil.net"
    static let publisherURL = URL(string: "https://inveil.net")!

    /// Support Oriel development.
    static let donateURL = URL(string: "https://paypal.me/macdirtycow")!
    static let supportURL = URL(string: "https://inveil.net")!
    static let privacyPolicyURL = URL(string: "https://openoriel.com")!

    static let startPageHost = "oriel.start"
    static let aboutScheme = "oriel"

    /// Chrome Web Store — on macOS, “Add to Oriel” installs via CRX download.
    static let chromeWebStoreURL = URL(string: "https://chromewebstore.google.com/")!

    /// Safari-like desktop UA for “Request Desktop Website” (keep relatively current).
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 15_2) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"
}
