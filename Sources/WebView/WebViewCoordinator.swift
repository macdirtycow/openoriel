import Foundation
import WebKit
#if os(iOS)
import UIKit
#endif

@MainActor
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var tab: BrowserTab
    var contentBlockingEnabled: Bool
    var matchesBlockedHint: (URL) -> Bool
    var onBlockedNavigation: () -> Void
    var onDownload: ((URL, String?) -> Void)?
    var permissionManager: WebsitePermissionManager?
    var onPopupCreated: ((WKWebView) -> Void)?
    var onPopupClosed: ((WKWebView) -> Void)?
    var onOpenURLInNewTab: ((URL) -> Void)?

    private var observations: [NSKeyValueObservation] = []
    private var popupTitleObservation: NSKeyValueObservation?

    init(
        tab: BrowserTab,
        contentBlockingEnabled: Bool = true,
        matchesBlockedHint: @escaping (URL) -> Bool = { _ in false },
        onBlockedNavigation: @escaping () -> Void = {},
        onDownload: ((URL, String?) -> Void)? = nil,
        permissionManager: WebsitePermissionManager? = nil,
        onPopupCreated: ((WKWebView) -> Void)? = nil,
        onPopupClosed: ((WKWebView) -> Void)? = nil,
        onOpenURLInNewTab: ((URL) -> Void)? = nil
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
        }
        let context = NavigationPolicy.Context(
            contentBlockingEnabled: contentBlockingEnabled,
            matchesBlockedHint: matchesBlockedHint,
            onBlocked: onBlockedNavigation
        )
        let policy = NavigationPolicy.decision(for: navigationAction, context: context)
        decisionHandler(policy, preferences)
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

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView === tab.webView, !tab.isShowingStartPage {
            tab.navigation.isLoading = false
            tab.navigation.estimatedProgress = 1
            tab.navigation.title = webView.title ?? ""
            if let url = webView.url {
                tab.navigation.url = url
                tab.navigation.syncAddressBarFromURL()
            }
            tab.onNavigationFinished?(tab)
            tab.applyPageEnhancementsAfterLoad()
        }
        if webView === tab.webView {
            tab.refreshNavigationChrome()
        }
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
            let copy = UIAction(title: "Copy Link", image: UIImage(systemName: "link")) { _ in
                UIPasteboard.general.url = linkURL
            }
            let download = UIAction(title: "Download Linked File", image: UIImage(systemName: "arrow.down.circle")) { _ in
                self?.onDownload?(linkURL, linkURL.lastPathComponent)
            }
            return UIMenu(title: "", children: [open, copy, download])
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
        let permission: SitePermission = {
            switch type {
            case .camera: return .camera
            case .microphone: return .microphone
            case .cameraAndMicrophone: return .camera
            @unknown default: return .camera
            }
        }()

        switch permissionManager?.decision(for: host, permission: permission) ?? .ask {
        case .allow:
            decisionHandler(.grant)
        case .deny:
            decisionHandler(.deny)
        case .ask:
            decisionHandler(.prompt)
        }
    }
}
