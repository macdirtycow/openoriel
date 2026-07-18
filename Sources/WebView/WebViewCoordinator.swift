import Foundation
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

private final class WeakHideElementHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebViewCoordinator?

    init(target: WebViewCoordinator) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = message.body
        Task { @MainActor [weak target] in
            target?.handleHideElementMessage(body)
        }
    }
}

/// Avoids a retain cycle: `WKUserContentController` strongly retains script message handlers.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebViewCoordinator?

    init(target: WebViewCoordinator) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let name = message.name
        let body = message.body
        Task { @MainActor [weak target] in
            target?.handleChromeWebStoreMessage(name: name, body: body)
        }
    }
}

@MainActor
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var tab: BrowserTab
    var contentBlockingEnabled: Bool
    var matchesBlockedHint: (URL) -> Bool
    var onBlockedNavigation: (URL) -> Void
    var onDownload: ((URL, String?) -> Void)?
    var permissionManager: WebsitePermissionManager?
    var onPopupCreated: ((WKWebView) -> Void)?
    var onPopupClosed: ((WKWebView) -> Void)?
    var onOpenURLInNewTab: ((URL) -> Void)?
    var onEnqueueURLForLater: ((URL) -> Void)?
    var shouldStripTracking: () -> Bool = { true }
    var shouldUseDuckPlayer: () -> Bool = { true }
    var onElementHidden: ((String, String) -> Void)?
    var onInstallChromeExtension: ((String) -> Void)?
    var onManageChromeExtensions: (() -> Void)?
    var installedChromeStoreIDs: [String] = []
    var youTubeAdBlockingEnabled: Bool = true
    var appliedThirdPartyCookieBlocking = false
    var appliedContentBlockerGeneration: Int = 0

    private var observations: [NSKeyValueObservation] = []
    private var popupTitleObservation: NSKeyValueObservation?
    private var chromeStoreMessageHandler: WeakScriptMessageHandler?
    private var lastStoreInstallRequestAt: Date?
    private var lastStoreInstallID: String?

    init(
        tab: BrowserTab,
        contentBlockingEnabled: Bool = true,
        matchesBlockedHint: @escaping (URL) -> Bool = { _ in false },
        onBlockedNavigation: @escaping (URL) -> Void = { _ in },
        onDownload: ((URL, String?) -> Void)? = nil,
        permissionManager: WebsitePermissionManager? = nil,
        onPopupCreated: ((WKWebView) -> Void)? = nil,
        onPopupClosed: ((WKWebView) -> Void)? = nil,
        onOpenURLInNewTab: ((URL) -> Void)? = nil,
        onEnqueueURLForLater: ((URL) -> Void)? = nil,
        shouldStripTracking: @escaping () -> Bool = { true },
        shouldUseDuckPlayer: @escaping () -> Bool = { true },
        onElementHidden: ((String, String) -> Void)? = nil,
        onInstallChromeExtension: ((String) -> Void)? = nil,
        onManageChromeExtensions: (() -> Void)? = nil,
        installedChromeStoreIDs: [String] = []
    ) {
        self.tab = tab
        self.contentBlockingEnabled = contentBlockingEnabled
        self.matchesBlockedHint = matchesBlockedHint
        self.onBlockedNavigation = onBlockedNavigation
        self.onDownload = onDownload
        self.permissionManager = permissionManager
        self.onPopupCreated = onPopupCreated
        self.onPopupClosed = onPopupClosed
        self.onOpenURLInNewTab = onOpenURLInNewTab
        self.onEnqueueURLForLater = onEnqueueURLForLater
        self.shouldStripTracking = shouldStripTracking
        self.shouldUseDuckPlayer = shouldUseDuckPlayer
        self.onElementHidden = onElementHidden
        self.onInstallChromeExtension = onInstallChromeExtension
        self.onManageChromeExtensions = onManageChromeExtensions
        self.installedChromeStoreIDs = installedChromeStoreIDs
    }

    /// Retained weakly by `WKUserContentController`; keep the proxy alive on the coordinator.
    func chromeWebStoreScriptMessageHandler() -> WKScriptMessageHandler {
        if let chromeStoreMessageHandler {
            return chromeStoreMessageHandler
        }
        let handler = WeakScriptMessageHandler(target: self)
        chromeStoreMessageHandler = handler
        return handler
    }

    func handleChromeWebStoreMessage(name: String, body: Any) {
        guard name == ChromeWebStoreBridge.handlerName else { return }
        let extensionID: String?
        if let body = body as? [String: Any] {
            extensionID = body["id"] as? String
        } else if let body = body as? String {
            extensionID = body
        } else {
            extensionID = nil
        }
        requestChromeExtensionInstall(extensionID)
    }

    func requestChromeExtensionInstall(_ rawID: String?) {
        guard let rawID, ChromeWebStoreAPI.isValidExtensionID(rawID.lowercased()) else { return }
        let id = rawID.lowercased()
        // messageHandlers + iframe fallback can fire twice for one click.
        if lastStoreInstallID == id,
           let lastStoreInstallRequestAt,
           Date().timeIntervalSince(lastStoreInstallRequestAt) < 2 {
            return
        }
        lastStoreInstallID = id
        lastStoreInstallRequestAt = Date()
        onInstallChromeExtension?(id)
    }

    func observe(_ webView: WKWebView) {
        observations.forEach { $0.invalidate() }
        observations = [
            webView.observe(\.canGoBack, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.tab.refreshNavigationChrome() }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.tab.refreshNavigationChrome() }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    guard let self, !self.tab.isShowingStartPage else { return }
                    self.tab.navigation.isLoading = webView.isLoading
                }
            },
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    guard let self, !self.tab.isShowingStartPage else { return }
                    self.tab.navigation.estimatedProgress = webView.estimatedProgress
                }
            },
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    guard let self, !self.tab.isShowingStartPage else { return }
                    self.tab.navigation.title = webView.title ?? ""
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if !self.tab.isShowingStartPage, let url = webView.url {
                        self.tab.navigation.url = url
                        self.tab.navigation.syncAddressBarFromURL()
                    }
                    self.tab.refreshNavigationChrome()
                }
            }
        ]
        tab.refreshNavigationChrome()
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        preferences: WKWebpagePreferences,
        decisionHandler: @escaping (WKNavigationActionPolicy, WKWebpagePreferences) -> Void
    ) {
        preferences.allowsContentJavaScript = tab.javaScriptEnabled
        if let url = navigationAction.request.url {
            let scheme = url.scheme?.lowercased() ?? ""
            if Self.externalURLSchemes.contains(scheme) {
                openExternalURL(url)
                decisionHandler(.cancel, preferences)
                return
            }

            #if os(macOS)
            if ChromeWebStoreAPI.isManageExtensionsURL(url) {
                onManageChromeExtensions?()
                decisionHandler(.cancel, preferences)
                return
            }
            if let extensionID = ChromeWebStoreAPI.extensionID(fromInstallURL: url) {
                requestChromeExtensionInstall(extensionID)
                decisionHandler(.cancel, preferences)
                return
            }
            #endif

            tab.syncUserAgentForNavigation(to: url)

            #if os(macOS)
            // ⌘-click opens links in a new tab (Safari/Chrome convention).
            if navigationAction.modifierFlags.contains(.command),
               navigationAction.targetFrame != nil,
               URLParser.isAllowedNavigation(url),
               !URLParser.isStartPage(url) {
                onOpenURLInNewTab?(url)
                decisionHandler(.cancel, preferences)
                return
            }
            #endif

            let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
            if isMainFrame,
               shouldStripTracking(),
               navigationAction.navigationType == .linkActivated
                || navigationAction.navigationType == .formSubmitted
                || navigationAction.navigationType == .other {
                let stripped = TrackingParameterStripper.strip(url, enabled: true)
                if stripped.didStrip {
                    decisionHandler(.cancel, preferences)
                    webView.load(URLRequest(url: stripped.url))
                    return
                }
            }

            if isMainFrame,
               shouldUseDuckPlayer(),
               DuckPlayer.isYouTubeWatchURL(url),
               let videoID = DuckPlayer.videoID(from: url) {
                decisionHandler(.cancel, preferences)
                tab.load(DuckPlayer.playerURL(forVideoID: videoID))
                return
            }
        }
        let context = NavigationPolicy.Context(
            contentBlockingEnabled: contentBlockingEnabled,
            matchesBlockedHint: matchesBlockedHint,
            onBlocked: onBlockedNavigation
        )
        let policy = NavigationPolicy.decision(for: navigationAction, context: context)
        decisionHandler(policy, preferences)
    }

    private static let externalURLSchemes: Set<String> = [
        "tel", "mailto", "sms", "facetime", "facetime-audio", "maps", "itms-apps", "itms"
    ]

    private func openExternalURL(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
        #elseif os(macOS)
        NSWorkspace.shared.open(url)
        #endif
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        if !navigationResponse.canShowMIMEType,
           let url = navigationResponse.response.url {
            onDownload?(url, navigationResponse.response.suggestedFilename)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if webView === tab.webView, !tab.isShowingStartPage {
            tab.navigation.isLoading = true
            tab.navigation.lastErrorMessage = nil
        }
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        injectYouTubeAdBlockIfNeeded(into: webView)
        injectPageCleanupIfNeeded(into: webView)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === tab.webView, !tab.isShowingStartPage {
            tab.navigation.isLoading = false
            tab.navigation.estimatedProgress = 1
            if URLParser.isDuckPlayerPage(tab.navigation.url) {
                tab.navigation.title = "Oriel Player"
            } else {
                tab.navigation.title = webView.title ?? ""
                if let url = webView.url {
                    tab.navigation.url = url
                    tab.navigation.syncAddressBarFromURL()
                }
            }
            tab.onNavigationFinished?(tab)
            tab.applyPageEnhancementsAfterLoad()
            tab.applyElementHideRules()
            #if os(macOS)
            injectInstalledExtensionIDs(into: webView)
            #endif
            injectYouTubeAdBlockIfNeeded(into: webView)
            injectPageCleanupIfNeeded(into: webView)
        }
        if webView === tab.webView {
            tab.refreshNavigationChrome()
        }
    }

    #if os(macOS)
    func injectInstalledExtensionIDs(into webView: WKWebView) {
        guard let host = webView.url?.host?.lowercased(),
              host == "chromewebstore.google.com"
                || host == "chrome.google.com"
                || host.hasSuffix(".chrome.google.com") else { return }
        let idsJSON = installedChromeStoreIDs
            .map { "\"\($0)\"" }
            .joined(separator: ",")
        let script = "window.__orielInstalledExtensionIDs = [\(idsJSON)];"
        webView.evaluateJavaScript(script, in: nil, in: .page) { _ in }
    }
    #endif


    func hideElementScriptMessageHandler() -> WKScriptMessageHandler {
        WeakHideElementHandler(target: self)
    }

    func handleHideElementMessage(_ body: Any) {
        guard let dict = body as? [String: Any],
              let selector = dict["selector"] as? String,
              let host = dict["host"] as? String,
              !selector.isEmpty,
              !host.isEmpty else { return }
        onElementHidden?(host, selector)
    }

    func injectYouTubeAdBlockIfNeeded(into webView: WKWebView) {
        guard youTubeAdBlockingEnabled, contentBlockingEnabled else {
            webView.evaluateJavaScript(YouTubeAdBlockScript.disableSource, in: nil, in: .page) { _ in }
            return
        }
        guard YouTubeAdBlockScript.shouldInject(for: webView.url) else { return }
        // Clear kill flag then (re)install — user script may already be present.
        let boot = "window.__orielYouTubeAdBlockKill = false;\n" + YouTubeAdBlockScript.source
        webView.evaluateJavaScript(boot, in: nil, in: .page) { _ in }
    }

    func injectPageCleanupIfNeeded(into webView: WKWebView) {
        guard contentBlockingEnabled else {
            webView.evaluateJavaScript(AdvancedPageCleanupScript.disableSource, in: nil, in: .page) { _ in }
            return
        }
        let boot =
            "window.__orielPageCleanupKill = false;\n"
            + "window.__orielPageCleanup = false;\n"
            + "window.__orielLarousseKillInstalled = false;\n"
            + AdvancedPageCleanupScript.documentStartSource
            + "\n"
            + AdvancedPageCleanupScript.source
        webView.evaluateJavaScript(boot, in: nil, in: .page) { _ in }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === tab.webView else { return }
        handleError(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        guard webView === tab.webView else { return }
        handleError(error)
    }

    private func handleError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }
        tab.navigation.isLoading = false
        tab.navigation.lastErrorMessage = nsError.localizedDescription
        tab.refreshNavigationChrome()
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Must return a WKWebView built with WebKit's configuration so Google OAuth
        // keeps cookies / opener linkage. Loading in the same tab breaks sign-in.
        let popup = WKWebView(frame: .zero, configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.allowsBackForwardNavigationGestures = true
        #if os(iOS)
        popup.scrollView.contentInsetAdjustmentBehavior = .automatic
        #endif

        popupTitleObservation?.invalidate()
        popupTitleObservation = popup.observe(\.title, options: [.new]) { [weak self] view, _ in
            Task { @MainActor in
                self?.onPopupTitleChanged?(view.title)
            }
        }

        onPopupCreated?(popup)
        return popup
    }

    var onPopupTitleChanged: ((String?) -> Void)?

    func webViewDidClose(_ webView: WKWebView) {
        onPopupClosed?(webView)
    }

    #if os(iOS)
    func webView(
        _ webView: WKWebView,
        contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
        completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
    ) {
        guard let linkURL = elementInfo.linkURL, URLParser.isAllowedNavigation(linkURL) else {
            completionHandler(nil)
            return
        }
        let config = UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            let open = UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square.on.square")) { _ in
                self?.onOpenURLInNewTab?(linkURL)
            }
            let later = UIAction(title: "Open Later", image: UIImage(systemName: "tray.and.arrow.down")) { _ in
                self?.onEnqueueURLForLater?(linkURL)
            }
            let copy = UIAction(title: "Copy Link", image: UIImage(systemName: "link")) { _ in
                UIPasteboard.general.url = linkURL
            }
            let download = UIAction(title: "Download Linked File", image: UIImage(systemName: "arrow.down.circle")) { _ in
                self?.onDownload?(linkURL, linkURL.lastPathComponent)
            }
            return UIMenu(title: "", children: [open, later, copy, download])
        }
        completionHandler(config)
    }
    #endif

    @available(iOS 15.0, macOS 12.0, *)
    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let host = origin.host
        let camera = permissionManager?.decision(for: host, permission: .camera) ?? .ask
        let microphone = permissionManager?.decision(for: host, permission: .microphone) ?? .ask

        let decision: PermissionDecision = {
            switch type {
            case .camera:
                return camera
            case .microphone:
                return microphone
            case .cameraAndMicrophone:
                if camera == .deny || microphone == .deny { return .deny }
                if camera == .allow && microphone == .allow { return .allow }
                return .ask
            @unknown default:
                return camera
            }
        }()

        switch decision {
        case .allow:
            decisionHandler(.grant)
        case .deny:
            decisionHandler(.deny)
        case .ask:
            decisionHandler(.prompt)
        }
    }

    @available(iOS 15.0, macOS 12.0, *)
    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        let host = origin.host
        switch permissionManager?.decision(for: host, permission: .location) ?? .ask {
        case .allow:
            decisionHandler(.grant)
        case .deny:
            decisionHandler(.deny)
        case .ask:
            decisionHandler(.prompt)
        }
    }
}
