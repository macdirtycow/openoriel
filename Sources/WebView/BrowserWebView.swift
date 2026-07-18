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
    var onInstallChromeExtension: ((String) -> Void)?
    var onManageChromeExtensions: (() -> Void)?
    var webExtensionController: AnyObject?
    var blockAutoplay: Bool = true
    var chromeWebStoreInstallEnabled: Bool = false
    var installedChromeStoreIDs: [String] = []

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
            onOpenURLInNewTab: onOpenURLInNewTab,
            onInstallChromeExtension: onInstallChromeExtension,
            onManageChromeExtensions: onManageChromeExtensions,
            installedChromeStoreIDs: installedChromeStoreIDs
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

        #if os(macOS)
        if chromeWebStoreInstallEnabled, !tab.isPrivate {
            let ucc = configuration.userContentController
            let handler = context.coordinator.chromeWebStoreScriptMessageHandler()
            ucc.removeScriptMessageHandler(forName: ChromeWebStoreBridge.handlerName, contentWorld: .page)
            ucc.removeScriptMessageHandler(forName: ChromeWebStoreBridge.handlerName, contentWorld: .defaultClient)
            // Page world: chrome.webstorePrivate stub. Client world: DOM “Add to Oriel” UI.
            ucc.add(handler, contentWorld: .page, name: ChromeWebStoreBridge.handlerName)
            ucc.add(handler, contentWorld: .defaultClient, name: ChromeWebStoreBridge.handlerName)

            let apiStub = WKUserScript(
                source: ChromeWebStoreBridge.chromeAPIStubSource,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true,
                in: .page
            )
            let uiBridge = WKUserScript(
                source: ChromeWebStoreBridge.userScriptSource,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true,
                in: .defaultClient
            )
            ucc.addUserScript(apiStub)
            ucc.addUserScript(uiBridge)
        }
        #endif

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
        context.coordinator.onInstallChromeExtension = onInstallChromeExtension
        context.coordinator.onManageChromeExtensions = onManageChromeExtensions
        context.coordinator.installedChromeStoreIDs = installedChromeStoreIDs
        #if os(macOS)
        context.coordinator.injectInstalledExtensionIDs(into: webView)
        #endif

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
