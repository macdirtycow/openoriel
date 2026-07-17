import Foundation
import WebKit

@MainActor
final class WebViewCoordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
    var tab: BrowserTab
    private var observations: [NSKeyValueObservation] = []

    init(tab: BrowserTab) {
        self.tab = tab
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
                        // Only overwrite address text when the field is not being edited aggressively;
                        // Phase 1 always syncs from WebKit.
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

    // MARK: - WKNavigationDelegate

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(NavigationPolicy.decision(for: navigationAction))
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

    // MARK: - WKUIDelegate

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        // Phase 1: open target=_blank in the same tab.
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if URLParser.isAllowedNavigation(url) {
                tab.load(url)
            }
        }
        return nil
    }
}
