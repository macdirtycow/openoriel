import Foundation
import WebKit

@MainActor
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var tab: BrowserTab
    var contentBlockingEnabled: Bool
    var matchesBlockedHint: (URL) -> Bool
    var onBlockedNavigation: () -> Void
    var onDownload: ((URL, String?) -> Void)?
    var permissionManager: WebsitePermissionManager?

    private var observations: [NSKeyValueObservation] = []

    init(
        tab: BrowserTab,
        contentBlockingEnabled: Bool = true,
        matchesBlockedHint: @escaping (URL) -> Bool = { _ in false },
        onBlockedNavigation: @escaping () -> Void = {},
        onDownload: ((URL, String?) -> Void)? = nil,
        permissionManager: WebsitePermissionManager? = nil
    ) {
        self.tab = tab
        self.contentBlockingEnabled = contentBlockingEnabled
        self.matchesBlockedHint = matchesBlockedHint
        self.onBlockedNavigation = onBlockedNavigation
        self.onDownload = onDownload
        self.permissionManager = permissionManager
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
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        let context = NavigationPolicy.Context(
            contentBlockingEnabled: contentBlockingEnabled,
            matchesBlockedHint: matchesBlockedHint,
            onBlocked: onBlockedNavigation
        )
        decisionHandler(NavigationPolicy.decision(for: navigationAction, context: context))
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
        if !tab.isShowingStartPage {
            tab.navigation.isLoading = true
            tab.navigation.lastErrorMessage = nil
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if !tab.isShowingStartPage {
            tab.navigation.isLoading = false
            tab.navigation.estimatedProgress = 1
            tab.navigation.title = webView.title ?? ""
            if let url = webView.url {
                tab.navigation.url = url
                tab.navigation.syncAddressBarFromURL()
            }
            tab.onNavigationFinished?(tab)
        }
        tab.refreshNavigationChrome()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        handleError(error)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
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
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if URLParser.isAllowedNavigation(url) {
                tab.load(url)
            }
        }
        return nil
    }

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
            // Default to prompt once; persist as ask until user sets in Shields.
            decisionHandler(.prompt)
        }
    }
}
