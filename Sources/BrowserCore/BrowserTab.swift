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

    /// Prefer desktop user agent for this tab when true.
    var requestsDesktopSite = false

    /// Weak reference so the SwiftUI `BrowserWebView` can drive load/back/forward.
    weak var webView: WKWebView?

    /// Optional callback when a page finishes loading (used for history).
    var onNavigationFinished: ((BrowserTab) -> Void)?

    /// Optional HTTPS upgrade + privacy hooks set by AppEnvironment.
    var shouldUpgradeHTTPS: ((URL) -> Bool)?
    var onHTTPSUpgrade: (() -> Void)?

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

    var isShowingStartPage: Bool {
        URLParser.isStartPage(navigation.url)
    }

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
            showStartPagePreservingWebHistory()
            return
        }

        guard URLParser.isAllowedNavigation(destination) else {
            navigation.lastErrorMessage = "This address uses an unsupported or blocked scheme."
            return
        }

        navigation.isLoading = true
        applyUserAgent()
        webView?.load(URLRequest(url: destination))
        refreshNavigationChrome()
    }

    func goBack() {
        // Start page is an app overlay — back returns to the live WKWebView page if any.
        if isShowingStartPage {
            if let webURL = webView?.url, !URLParser.isStartPage(webURL) {
                navigation.lastErrorMessage = nil
                navigation.url = webURL
                navigation.title = webView?.title ?? webURL.host ?? BrowserConstants.productName
                navigation.syncAddressBarFromURL()
                refreshNavigationChrome()
                return
            }
        }

        guard let webView, webView.canGoBack else { return }
        webView.goBack()
        refreshNavigationChrome()
    }

    func goForward() {
        guard let webView, webView.canGoForward else { return }
        // Leaving start page via forward isn't typical; if web can go forward, show web content.
        if isShowingStartPage, let webURL = webView.url {
            navigation.url = webURL
            navigation.syncAddressBarFromURL()
        }
        webView.goForward()
        refreshNavigationChrome()
    }

    func reload() {
        if isShowingStartPage { return }
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

    func toggleDesktopSite() {
        requestsDesktopSite.toggle()
        applyUserAgent()
        if !isShowingStartPage {
            webView?.reload()
        }
    }

    func findInPage(_ query: String, forward: Bool = true) {
        guard !query.isEmpty else {
            clearFindInPage()
            return
        }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView?.find(query, configuration: config) { _ in }
    }

    func clearFindInPage() {
        #if os(macOS)
        // WKWebView has no public clear-highlights API on all platforms; empty find is best-effort.
        #endif
        let config = WKFindConfiguration()
        webView?.find("", configuration: config) { _ in }
    }

    /// Call after WebKit navigation changes so toolbar buttons stay accurate.
    func refreshNavigationChrome() {
        let web = webView
        if isShowingStartPage {
            // From start page, Back is available when a real page is still loaded underneath.
            let hasUnderlyingPage: Bool = {
                guard let url = web?.url else { return false }
                return !URLParser.isStartPage(url)
            }()
            navigation.canGoBack = hasUnderlyingPage || (web?.canGoBack ?? false)
            navigation.canGoForward = web?.canGoForward ?? false
            navigation.isLoading = false
            navigation.estimatedProgress = 0
        } else {
            navigation.canGoBack = web?.canGoBack ?? false
            navigation.canGoForward = web?.canGoForward ?? false
            if let web {
                navigation.isLoading = web.isLoading
                navigation.estimatedProgress = web.estimatedProgress
            }
        }
    }

    private func showStartPagePreservingWebHistory() {
        navigation.isLoading = false
        navigation.estimatedProgress = 0
        navigation.title = BrowserConstants.productName
        navigation.lastErrorMessage = nil
        // Do not ask WKWebView to load oriel:// — keep the previous page in the web view.
        webView?.stopLoading()
        refreshNavigationChrome()
    }

    private func applyUserAgent() {
        guard let webView else { return }
        if requestsDesktopSite {
            webView.customUserAgent = BrowserConstants.desktopUserAgent
        } else {
            webView.customUserAgent = nil
        }
    }
}
