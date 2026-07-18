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
    var contentRuleLists: [WKContentRuleList] = []
    var blockThirdPartyCookies: Bool = false
    var fingerprintingProtection: Bool = true
    var contentBlockingEnabled: Bool = true
    var matchesBlockedHint: (URL) -> Bool = { _ in false }
    var onBlockedNavigation: (URL) -> Void = { _ in }
    var onDownload: ((URL, String?) -> Void)?
    var permissionManager: WebsitePermissionManager?
    var onPopupCreated: ((WKWebView) -> Void)?
    var onPopupClosed: ((WKWebView) -> Void)?
    var onPopupTitleChanged: ((String?) -> Void)?
    var onOpenURLInNewTab: ((URL) -> Void)?
    var onEnqueueURLForLater: ((URL) -> Void)?
    var shouldStripTracking: () -> Bool = { true }
    var onElementHidden: ((String, String) -> Void)?
    var onInstallChromeExtension: ((String) -> Void)?
    var onManageChromeExtensions: (() -> Void)?
    var webExtensionController: AnyObject?
    var blockAutoplay: Bool = true
    var chromeWebStoreInstallEnabled: Bool = false
    var installedChromeStoreIDs: [String] = []
    var applyContentBlocking: ((WKWebView, Bool) -> Void)?
    /// Bumps when compiled rule lists change so existing tabs re-attach them.
    var contentBlockerGeneration: Int = 0
    /// Isolated cookie/storage jar for the active browser profile.
    var websiteDataStore: WKWebsiteDataStore?

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
            onEnqueueURLForLater: onEnqueueURLForLater,
            shouldStripTracking: shouldStripTracking,
            onElementHidden: onElementHidden,
            onInstallChromeExtension: onInstallChromeExtension,
            onManageChromeExtensions: onManageChromeExtensions,
            installedChromeStoreIDs: installedChromeStoreIDs
        )
    }

    private func makeWebView(context: Context) -> WKWebView {
        let configuration = SharedWebViewConfiguration.make(
            isPrivate: tab.isPrivate,
            javaScriptEnabled: tab.javaScriptEnabled,
            contentRuleLists: contentRuleLists,
            contentBlockingEnabled: contentBlockingEnabled,
            blockAutoplay: blockAutoplay,
            fingerprintingProtection: fingerprintingProtection,
            webExtensionController: webExtensionController,
            websiteDataStore: websiteDataStore ?? (tab.isPrivate ? .nonPersistent() : .default())
        )

        #if os(macOS) || os(iOS)
        if chromeWebStoreInstallEnabled, !tab.isPrivate {
            let ucc = configuration.userContentController
            let handler = context.coordinator.chromeWebStoreScriptMessageHandler()
            ucc.removeScriptMessageHandler(forName: ChromeWebStoreBridge.handlerName, contentWorld: .page)
            ucc.removeScriptMessageHandler(forName: ChromeWebStoreBridge.handlerName, contentWorld: .defaultClient)
            ucc.add(handler, contentWorld: .page, name: ChromeWebStoreBridge.handlerName)

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
                in: .page
            )
            ucc.addUserScript(apiStub)
            ucc.addUserScript(uiBridge)
        }
        #endif

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        // Keep the web view clear so themed start-page washes aren't covered by opaque white/black.
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        #elseif os(macOS)
        webView.underPageBackgroundColor = .clear
        #endif

        if tab.requestsDesktopSite || UserAgentPolicy.isGoogleHost(tab.navigation.url?.host) {
            webView.customUserAgent = UserAgentPolicy.customUserAgent(
                for: tab.navigation.url,
                requestsDesktopSite: tab.requestsDesktopSite
            )
        }

        let hideHandler = context.coordinator.hideElementScriptMessageHandler()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "orielHideElement")
        webView.configuration.userContentController.add(hideHandler, contentWorld: .page, name: "orielHideElement")

        context.coordinator.observe(webView)
        context.coordinator.onPopupTitleChanged = onPopupTitleChanged
        context.coordinator.youTubeAdBlockingEnabled = contentBlockingEnabled
        context.coordinator.appliedContentBlockerGeneration = contentBlockerGeneration
        context.coordinator.appliedThirdPartyCookieBlocking = blockThirdPartyCookies
        tab.webView = webView
        tab.refreshNavigationChrome()

        Task { @MainActor in
            await ThirdPartyCookieBlocker.apply(to: webView, enabled: blockThirdPartyCookies)
        }

        if let url = tab.navigation.url, !URLParser.isStartPage(url) {
            webView.load(URLRequest(url: url))
        }

        return webView
    }

    private func updateWebView(_ webView: WKWebView, context: Context) {
        if tab.webView !== webView {
            tab.webView = webView
        }
        let blockingChanged = context.coordinator.contentBlockingEnabled != contentBlockingEnabled
        let listsChanged = context.coordinator.appliedContentBlockerGeneration != contentBlockerGeneration
        context.coordinator.tab = tab
        context.coordinator.contentBlockingEnabled = contentBlockingEnabled
        context.coordinator.youTubeAdBlockingEnabled = contentBlockingEnabled
        context.coordinator.matchesBlockedHint = matchesBlockedHint
        context.coordinator.onBlockedNavigation = onBlockedNavigation
        context.coordinator.onDownload = onDownload
        context.coordinator.permissionManager = permissionManager
        context.coordinator.onPopupCreated = onPopupCreated
        context.coordinator.onPopupClosed = onPopupClosed
        context.coordinator.onPopupTitleChanged = onPopupTitleChanged
        context.coordinator.onOpenURLInNewTab = onOpenURLInNewTab
        context.coordinator.onEnqueueURLForLater = onEnqueueURLForLater
        context.coordinator.shouldStripTracking = shouldStripTracking
        context.coordinator.onElementHidden = onElementHidden
        context.coordinator.onInstallChromeExtension = onInstallChromeExtension
        context.coordinator.onManageChromeExtensions = onManageChromeExtensions
        context.coordinator.installedChromeStoreIDs = installedChromeStoreIDs
        #if os(macOS)
        context.coordinator.injectInstalledExtensionIDs(into: webView)
        #endif

        if blockingChanged || (contentBlockingEnabled && listsChanged && !contentRuleLists.isEmpty) {
            applyContentBlocking?(webView, contentBlockingEnabled)
            context.coordinator.appliedContentBlockerGeneration = contentBlockerGeneration
            if contentBlockingEnabled {
                context.coordinator.injectYouTubeAdBlockIfNeeded(into: webView)
                webView.evaluateJavaScript(AdvancedPageCleanupScript.documentStartSource, in: nil, in: .page) { _ in }
                webView.evaluateJavaScript(AdvancedPageCleanupScript.source, in: nil, in: .page) { _ in }
            } else {
                webView.evaluateJavaScript(YouTubeAdBlockScript.disableSource, in: nil, in: .page) { _ in }
                webView.evaluateJavaScript(AdvancedPageCleanupScript.disableSource, in: nil, in: .page) { _ in }
            }
        }

        if context.coordinator.appliedThirdPartyCookieBlocking != blockThirdPartyCookies {
            context.coordinator.appliedThirdPartyCookieBlocking = blockThirdPartyCookies
            Task { @MainActor in
                await ThirdPartyCookieBlocker.apply(to: webView, enabled: blockThirdPartyCookies)
            }
        }

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
