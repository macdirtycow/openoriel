import Foundation
import WebKit

@MainActor
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var tab: BrowserTab
    var contentBlockingEnabled: Bool
    var matchesBlockedHint: (URL) -> Bool
    var onBlockedNavigation: () -> Void
    private var observations: [NSKeyValueObservation] = []

    init(
        tab: BrowserTab,
        contentBlockingEnabled: Bool = true,
        matchesBlockedHint: @escaping (URL) -> Bool = { _ in false },
        onBlockedNavigation: @escaping () -> Void = {}
    ) {
        self.tab = tab
        self.contentBlockingEnabled = contentBlockingEnabled
        self.matchesBlockedHint = matchesBlockedHint
        self.onBlockedNavigation = onBlockedNavigation
    }

    func observe(_ webView: WKWebView) {
        observations.forEach { $0.invalidate() }
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.navigation.estimatedProgress = webView.estimatedProgress
                }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.navigation.isLoading = webView.isLoading
                }
            },
            webView.observe(\.title, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.navigation.title = webView.title ?? ""
                }
            },
            webView.observe(\.url, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    guard let self else { return }
                    if let url = webView.url {
                        self.tab.navigation.url = url
                        self.tab.navigation.syncAddressBarFromURL()
                    }
                }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.navigation.canGoBack = webView.canGoBack
                }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] webView, _ in
                Task { @MainActor in
                    self?.tab.navigation.canGoForward = webView.canGoForward
                }
            }
        ]
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

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        tab.navigation.isLoading = true
        tab.navigation.lastErrorMessage = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        tab.navigation.isLoading = false
        tab.navigation.estimatedProgress = 1
        tab.navigation.title = webView.title ?? ""
        if let url = webView.url {
            tab.navigation.url = url
            tab.navigation.syncAddressBarFromURL()
        }
        tab.navigation.canGoBack = webView.canGoBack
        tab.navigation.canGoForward = webView.canGoForward
        tab.onNavigationFinished?(tab)
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
}
