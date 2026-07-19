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
    var fingerprintingProtection: Bool = false
    var contentBlockingEnabled: Bool = true
    var trackerProbeHosts: [String] = TrackerHitProbe.seedHosts
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
    var onInstallFirefoxAddon: ((String) -> Void)?
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
    /// Configuration fingerprint used by `WebViewPool` (profile / fingerprinting / autoplay).
    var poolConfigKey: String = "default"
    /// Tab IDs that must not be evicted while this view is alive (active + split).
    var protectedTabIDs: Set<UUID> = []

    #if os(iOS)
    func makeUIView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: WebViewCoordinator) {
        // Keep the WKWebView in the pool — do not release on tab switch.
        uiView.navigationDelegate = nil
        uiView.uiDelegate = nil
    }
    #elseif os(macOS)
    func makeNSView(context: Context) -> WKWebView {
        makeWebView(context: context)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        updateWebView(webView, context: context)
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: WebViewCoordinator) {
        nsView.navigationDelegate = nil
        nsView.uiDelegate = nil
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
            onInstallFirefoxAddon: onInstallFirefoxAddon,
            onManageChromeExtensions: onManageChromeExtensions,
            installedChromeStoreIDs: installedChromeStoreIDs
        )
    }

    private func makeWebView(context: Context) -> WKWebView {
        if let pooled = WebViewPool.shared.existing(for: tab.id, configKey: poolConfigKey) {
            return attach(pooled, context: context, isReuse: true)
        }

        let configuration = SharedWebViewConfiguration.make(
            isPrivate: tab.isPrivate,
            javaScriptEnabled: tab.javaScriptEnabled,
            contentRuleLists: contentRuleLists,
            contentBlockingEnabled: contentBlockingEnabled,
            blockAutoplay: blockAutoplay,
            fingerprintingProtection: fingerprintingProtection,
            trackerProbeHosts: trackerProbeHosts,
            webExtensionController: webExtensionController,
            websiteDataStore: websiteDataStore ?? (tab.isPrivate ? .nonPersistent() : .default())
        )

        #if os(macOS) || os(iOS)
        if chromeWebStoreInstallEnabled, !tab.isPrivate {
            installStoreBridges(
                into: configuration.userContentController,
                context: context,
                includeUserScripts: true
            )
        }
        #endif

        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Keep the web view clear so themed start-page washes aren't covered by opaque white/black.
        #if os(iOS)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        #elseif os(macOS)
        webView.underPageBackgroundColor = .clear
        #endif

        webView.allowsBackForwardNavigationGestures = true
        let attached = attach(webView, context: context, isReuse: false)
        WebViewPool.shared.store(
            attached,
            for: tab.id,
            configKey: poolConfigKey,
            protecting: protectedTabIDs
        )

        Task { @MainActor in
            await ThirdPartyCookieBlocker.apply(to: attached, enabled: blockThirdPartyCookies)
        }

        if let url = tab.navigation.url, !URLParser.isStartPage(url) {
            attached.load(URLRequest(url: url))
        }

        return attached
    }

    private func attach(_ webView: WKWebView, context: Context, isReuse: Bool) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator

        if tab.requestsDesktopSite {
            webView.customUserAgent = UserAgentPolicy.customUserAgent(
                for: tab.navigation.url,
                requestsDesktopSite: true
            )
        }

        #if os(macOS) || os(iOS)
        if chromeWebStoreInstallEnabled, !tab.isPrivate {
            // User scripts already live on a reused configuration; only rebind handlers.
            installStoreBridges(
                into: webView.configuration.userContentController,
                context: context,
                includeUserScripts: false
            )
        }
        #endif

        let hideHandler = context.coordinator.hideElementScriptMessageHandler()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "orielHideElement")
        webView.configuration.userContentController.add(hideHandler, contentWorld: .page, name: "orielHideElement")

        let trackerHandler = context.coordinator.trackerHitScriptMessageHandler()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: TrackerHitProbe.handlerName)
        webView.configuration.userContentController.add(
            trackerHandler,
            contentWorld: .page,
            name: TrackerHitProbe.handlerName
        )

        context.coordinator.observe(webView)
        context.coordinator.onPopupTitleChanged = onPopupTitleChanged
        context.coordinator.youTubeAdBlockingEnabled = contentBlockingEnabled
        context.coordinator.appliedContentBlockerGeneration = contentBlockerGeneration
        context.coordinator.appliedThirdPartyCookieBlocking = blockThirdPartyCookies
        tab.webView = webView
        tab.refreshNavigationChrome()
        WebViewPool.shared.touch(tab.id)

        if isReuse {
            // Re-apply rule lists that may have compiled while this tab was detached.
            applyContentBlocking?(webView, contentBlockingEnabled)
        }

        return webView
    }

    #if os(macOS) || os(iOS)
    private func installStoreBridges(
        into ucc: WKUserContentController,
        context: Context,
        includeUserScripts: Bool
    ) {
        let handler = context.coordinator.chromeWebStoreScriptMessageHandler()
        ucc.removeScriptMessageHandler(forName: ChromeWebStoreBridge.handlerName, contentWorld: .page)
        ucc.removeScriptMessageHandler(forName: ChromeWebStoreBridge.handlerName, contentWorld: .defaultClient)
        ucc.add(handler, contentWorld: .page, name: ChromeWebStoreBridge.handlerName)

        let firefoxHandler = context.coordinator.firefoxAddonsScriptMessageHandler()
        ucc.removeScriptMessageHandler(forName: FirefoxAddonsBridge.handlerName, contentWorld: .page)
        ucc.removeScriptMessageHandler(forName: FirefoxAddonsBridge.handlerName, contentWorld: .defaultClient)
        ucc.add(firefoxHandler, contentWorld: .page, name: FirefoxAddonsBridge.handlerName)

        guard includeUserScripts else { return }
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
        let firefoxSpoof = WKUserScript(
            source: FirefoxAddonsBridge.desktopSpoofSource,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true,
            in: .page
        )
        let firefoxBridge = WKUserScript(
            source: FirefoxAddonsBridge.userScriptSource,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true,
            in: .page
        )
        ucc.addUserScript(apiStub)
        ucc.addUserScript(uiBridge)
        ucc.addUserScript(firefoxSpoof)
        ucc.addUserScript(firefoxBridge)
    }
    #endif

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
        context.coordinator.onInstallFirefoxAddon = onInstallFirefoxAddon
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
