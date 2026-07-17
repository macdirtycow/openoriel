import Foundation
import Observation
import WebKit

/// A single browser tab managed by `TabManager`.
@Observable
@MainActor
final class BrowserTab: Identifiable {
    let id: UUID
    let isPrivate: Bool
    var searchEngine: SearchEngine
    var navigation = NavigationState()

    /// Weak reference so the SwiftUI `BrowserWebView` can drive load/back/forward.
    weak var webView: WKWebView?

    /// Optional callback when a page finishes loading (used for history).
    var onNavigationFinished: ((BrowserTab) -> Void)?

    init(
        id: UUID = UUID(),
        isPrivate: Bool = false,
        searchEngine: SearchEngine = .duckDuckGo,
        initialURL: URL? = nil
    ) {
        self.id = id
        self.isPrivate = isPrivate
        self.searchEngine = searchEngine
        if let initialURL {
            navigation.url = initialURL
            navigation.syncAddressBarFromURL()
            if !URLParser.isStartPage(initialURL) {
                navigation.title = initialURL.host ?? BrowserConstants.productName
            } else {
                navigation.title = BrowserConstants.productName
            }
        } else {
            navigation.url = URLParser.startPageURL
            navigation.addressBarText = ""
            navigation.title = BrowserConstants.productName
        }
    }

    var displayTitle: String {
        navigation.displayTitle
    }

    var restorableURL: URL {
        navigation.url ?? URLParser.startPageURL
    }

    /// Optional HTTPS upgrade + privacy hooks set by AppEnvironment.
    var shouldUpgradeHTTPS: ((URL) -> Bool)?
    var onHTTPSUpgrade: (() -> Void)?

    func submitAddressBar() {
        let url = URLParser.resolve(navigation.addressBarText, searchEngine: searchEngine)
        load(url)
    }

    func load(_ url: URL) {
        navigation.lastErrorMessage = nil

        var destination = url
        if !URLParser.isStartPage(url) {
            let upgradeEnabled = shouldUpgradeHTTPS?(destination) ?? true
            let result = HTTPSUpgrade.upgradeIfNeeded(destination, enabled: upgradeEnabled)
            if result.didUpgrade {
                destination = result.url
                onHTTPSUpgrade?()
            }
        }

        navigation.url = destination
        navigation.syncAddressBarFromURL()

        if URLParser.isStartPage(destination) {
            navigation.isLoading = false
            navigation.estimatedProgress = 0
            navigation.title = BrowserConstants.productName
            return
        }

        guard URLParser.isAllowedNavigation(destination) else {
            navigation.lastErrorMessage = "This address uses an unsupported or blocked scheme."
            return
        }

        navigation.isLoading = true
        webView?.load(URLRequest(url: destination))
    }

    func goBack() {
        webView?.goBack()
    }

    func goForward() {
        webView?.goForward()
    }

    func reload() {
        if URLParser.isStartPage(navigation.url) {
            return
        }
        if navigation.lastErrorMessage != nil, let url = navigation.url {
            load(url)
            return
        }
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
        navigation.isLoading = false
    }

    func goHome() {
        load(URLParser.startPageURL)
    }

    func openProductSite() {
        load(BrowserConstants.productWebsiteURL)
    }

    func openPublisherSite() {
        load(BrowserConstants.publisherURL)
    }
}
