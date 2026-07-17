import Foundation

enum BrowserConstants {
    static let productName = "Oriel"
    /// Official product domain (openoriel.com).
    static let productWebsiteHost = "openoriel.com"
    static let productWebsiteURL = URL(string: "https://openoriel.com")!

    /// Company that builds Oriel.
    static let publisherName = "inveil.net"
    static let publisherURL = URL(string: "https://inveil.net")!

    static let startPageHost = "oriel.start"
    static let aboutScheme = "oriel"

    /// Safari-like desktop Safari UA for “Request Desktop Website”.
    static let desktopUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
}
