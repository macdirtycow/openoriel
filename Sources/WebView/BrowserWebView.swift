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
    var blockThirdPartyCookies: Bool = false
    var contentBlockingEnabled: Bool = true
    var matchesBlockedHint: (URL) -> Bool = { _ in false }
    var onBlockedNavigation: () -> Void = {}
    var onDownload: ((URL, String?) -> Void)?
    var permissionManager: WebsitePermissionManager?
    var onPopupCreated: ((WKWebView) -> Void)?
    var onPopupClosed: ((WKWebView) -> Void)?
    var onPopupTitleChanged: ((String?) -> Void)?
    var onOpenURLInNewTab: ((URL) -> Void)?
    var webExtensionController: AnyObject?
    var blockAutoplay: Bool = true

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
            onBlockedNavigation: onBlockedNavigation,
            onDownload: onDownload,
            permissionManager: permissionManager,
            onPopupCreated: onPopupCreated,
            onPopupClosed: onPopupClosed,
            onOpenURLInNewTab: onOpenURLInNewTab
        )
    }

    private func makeWebView(context: Context) -> WKWebView {
        let configuration = SharedWebViewConfiguration.make(
            isPrivate: tab.isPrivate,
            javaScriptEnabled: tab.javaScriptEnabled,
            contentRuleList: contentRuleList,
            contentBlockingEnabled: contentBlockingEnabled,
            blockAutoplay: blockAutoplay,
            webExtensionController: webExtensionController
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        #endif

        if tab.requestsDesktopSite || UserAgentPolicy.isGoogleHost(tab.navigation.url?.host) {
            webView.customUserAgent = UserAgentPolicy.customUserAgent(
                for: tab.navigation.url,
                requestsDesktopSite: tab.requestsDesktopSite
            )
        }

        context.coordinator.observe(webView)
        context.coordinator.onPopupTitleChanged = onPopupTitleChanged
        tab.webView = webView
        tab.refreshNavigationChrome()

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
        context.coordinator.onDownload = onDownload
        context.coordinator.permissionManager = permissionManager
        context.coordinator.onPopupCreated = onPopupCreated
        context.coordinator.onPopupClosed = onPopupClosed
        context.coordinator.onPopupTitleChanged = onPopupTitleChanged
        context.coordinator.onOpenURLInNewTab = onOpenURLInNewTab

        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = tab.javaScriptEnabled

        let desiredUA = UserAgentPolicy.customUserAgent(
            for: tab.navigation.url,
            requestsDesktopSite: tab.requestsDesktopSite
        )
        if webView.customUserAgent != desiredUA {
            webView.customUserAgent = desiredUA
        }
    }
}
