import SwiftUI
import WebKit

#if os(iOS)
typealias PlatformViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias PlatformViewRepresentable = NSViewRepresentable
#endif

/// SwiftUI wrapper around WKWebView, bound to a `BrowserTab`.
struct BrowserWebView: PlatformViewRepresentable {
    let tab: BrowserTab
    var contentRuleList: WKContentRuleList?
    var blockThirdPartyCookies: Bool = true
    var contentBlockingEnabled: Bool = true
    var matchesBlockedHint: (URL) -> Bool = { _ in false }
    var onBlockedNavigation: () -> Void = {}

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }
    #endif

    func makeCoordinator() -> WebViewCoordinator {
        WebViewCoordinator(
            tab: tab,
            contentBlockingEnabled: contentBlockingEnabled,
            matchesBlockedHint: matchesBlockedHint,
            onBlockedNavigation: onBlockedNavigation
        )
    }

    private func makeWebView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = tab.isPrivate
            ? .nonPersistent()
            : .default()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.preferences.isElementFullscreenEnabled = true

        if blockThirdPartyCookies {
            // Best-effort: prefer stricter cookie accept policy where available.
            configuration.websiteDataStore.httpCookieStore.getAllCookies { _ in }
        }

        if contentBlockingEnabled, let contentRuleList {
            configuration.userContentController.add(contentRuleList)
        }

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        #endif

        context.coordinator.observe(webView)
        tab.webView = webView

        if let url = tab.navigation.url, !URLParser.isStartPage(url) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    private func updateWebView(_ webView: WKWebView, context: Context) {
        if tab.webView !== webView {
            tab.webView = webView
        }
        context.coordinator.tab = tab
        context.coordinator.contentBlockingEnabled = contentBlockingEnabled
        context.coordinator.matchesBlockedHint = matchesBlockedHint
        context.coordinator.onBlockedNavigation = onBlockedNavigation
    }
}
