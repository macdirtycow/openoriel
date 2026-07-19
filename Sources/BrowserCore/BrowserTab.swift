import Foundation
import Observation
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// A single browser tab managed by `TabManager`.
@Observable
@MainActor
final class BrowserTab: Identifiable {
    let id: UUID
    let isPrivate: Bool
    var searchEngine: SearchEngine
    var navigation = NavigationState()

    /// Prefer desktop user agent for this tab when true.
    var requestsDesktopSite = false

    /// When false, page scripts are blocked (reload required to apply).
    var javaScriptEnabled = true

    /// Pinned tabs stay toward the front of the strip / overview.
    var isPinned = false

    /// Optional tab group membership.
    var groupID: UUID?

    /// Page zoom factor (1.0 = actual size).
    var zoomFactor: Double = 1.0

    var forceDarkEnabled = false
    var lucidModeEnabled = false
    var isReaderMode = false
    /// When true, media in this tab is forced muted.
    var isMediaMuted = false
    /// Last find-in-page match count (approx); `nil` when inactive.
    var findMatchCount: Int?
    var findMatchFound = false
    /// Mirrors Settings preferred engine for UA (WebKit vs Chromium Compatible).
    var preferredEngine: BrowserEngineKind = .webkit
    /// Optional per-tab lock; `nil` follows global + site policy.
    var engineOverride: BrowserEngineKind?

    /// Quiet browsing: mute media, pause playback, hide noisy sticky UI.
    var isFocusMode = false

    /// Weak reference so the SwiftUI `BrowserWebView` can drive load/back/forward.
    weak var webView: WKWebView?

    /// Optional callback when a page finishes loading (used for history).
    var onNavigationFinished: ((BrowserTab) -> Void)?

    /// Optional HTTPS upgrade + privacy hooks set by AppEnvironment.
    var shouldUpgradeHTTPS: ((URL) -> Bool)?
    var onHTTPSUpgrade: (() -> Void)?
    var shouldStripTracking: (() -> Bool)?
    var isHTTPSOnlyMode: (() -> Bool)?
    var elementHideScript: (() -> String)?
    /// Refresh `preferredEngine` from global/site/tab policy before UA apply.
    /// Passes the destination URL so Smart mode can pick per navigation, not the previous page.
    var onResolveEngine: ((BrowserTab, URL?) -> Void)?
    /// When true, cancel navigation and open system Chromium for this URL.
    var shouldHandOffToSystemChromium: ((URL) -> Bool)?
    var onHandOffToSystemChromium: ((URL) -> Void)?
    /// Per-host zoom lookup / save (wired by AppEnvironment).
    var siteZoomProvider: ((String?) -> Double)?
    var onZoomChanged: ((String?, Double) -> Void)?
    /// Called after load enhancements (zoom / mute / dark) so governors can inject.
    var onPageEnhanced: ((BrowserTab) -> Void)?

    init(
        id: UUID = UUID(),
        isPrivate: Bool = false,
        searchEngine: SearchEngine = .duckDuckGo,
        initialURL: URL? = nil
    ) {
        self.id = id
        self.isPrivate = isPrivate
        self.searchEngine = searchEngine
        if let initialURL {
            navigation.url = initialURL
            navigation.syncAddressBarFromURL()
            if !URLParser.isStartPage(initialURL) {
                navigation.title = initialURL.host ?? BrowserConstants.productName
            } else {
                navigation.title = BrowserConstants.productName
            }
        } else {
            navigation.url = URLParser.startPageURL
            navigation.addressBarText = ""
            navigation.title = BrowserConstants.productName
        }
    }

    var displayTitle: String {
        navigation.displayTitle
    }

    var restorableURL: URL {
        navigation.url ?? URLParser.startPageURL
    }

    var isShowingStartPage: Bool {
        URLParser.isStartPage(navigation.url)
    }

    func submitAddressBar() {
        let url = URLParser.resolve(navigation.addressBarText, searchEngine: searchEngine)
        load(url)
    }

    func load(_ url: URL) {
        navigation.lastErrorMessage = nil

        var destination = url
        if !URLParser.isStartPage(url) {
            let upgradeEnabled = (shouldUpgradeHTTPS?(destination) ?? true) || (isHTTPSOnlyMode?() ?? false)
            let result = HTTPSUpgrade.upgradeIfNeeded(destination, enabled: upgradeEnabled)
            if result.didUpgrade {
                destination = result.url
                onHTTPSUpgrade?()
            }

            if isHTTPSOnlyMode?() == true,
               destination.scheme?.lowercased() == "http",
               let host = destination.host?.lowercased(),
               host != "localhost",
               !host.hasSuffix(".local") {
                navigation.url = destination
                navigation.syncAddressBarFromURL()
                navigation.isLoading = false
                navigation.lastErrorMessage = "HTTPS-Only Mode blocked this insecure (HTTP) page."
                refreshNavigationChrome()
                return
            }

            let stripEnabled = shouldStripTracking?() ?? true
            let stripped = TrackingParameterStripper.strip(destination, enabled: stripEnabled)
            if stripped.didStrip {
                destination = stripped.url
            }
        }

        if URLParser.isStartPage(destination) {
            navigation.url = destination
            navigation.syncAddressBarFromURL()
            showStartPagePreservingWebHistory()
            return
        }

        guard URLParser.isAllowedNavigation(destination) else {
            navigation.lastErrorMessage = "This address uses an unsupported or blocked scheme."
            return
        }

        // Hand off before mutating local navigation — avoids address-bar/content desync.
        if shouldHandOffToSystemChromium?(destination) == true {
            #if os(macOS)
            if ChromiumEngineBridge.systemChromiumInstalled {
                onHandOffToSystemChromium?(destination)
                return
            }
            #endif
        }

        navigation.url = destination
        navigation.syncAddressBarFromURL()

        navigation.isLoading = true
        applyUserAgent(for: destination)
        webView?.load(URLRequest(url: destination))
        refreshNavigationChrome()
    }

    func startElementPicker() {
        webView?.evaluateJavaScript(ElementHideStore.pickerSource, in: nil, in: .page) { _ in }
    }

    func cancelElementPicker() {
        webView?.evaluateJavaScript(ElementHideStore.cancelPickerSource, in: nil, in: .page) { _ in }
    }

    func applyElementHideRules() {
        guard let script = elementHideScript?(), !script.isEmpty else { return }
        webView?.evaluateJavaScript(script, in: nil, in: .page) { _ in }
    }

    func togglePictureInPicture() {
        webView?.evaluateJavaScript(PictureInPictureScript.enableBest, in: nil, in: .page) { _ in }
    }

    func togglePictureInPicture(at index: Int) {
        webView?.evaluateJavaScript(PictureInPictureScript.toggle(at: index), in: nil, in: .page) { _ in }
    }

    func listPictureInPictureVideos(completion: @escaping ([[String: Any]]) -> Void) {
        guard let webView else {
            completion([])
            return
        }
        webView.evaluateJavaScript(PictureInPictureScript.inventory, in: nil, in: .page) { result in
            switch result {
            case .success(let value):
                guard let json = value as? String,
                      let data = json.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let videos = obj["videos"] as? [[String: Any]] else {
                    completion([])
                    return
                }
                completion(videos)
            case .failure:
                completion([])
            }
        }
    }

    func enableMediaControls() {
        webView?.evaluateJavaScript(PictureInPictureScript.mediaControls, in: nil, in: .page) { _ in }
    }

    func setReaderFontSize(_ size: String) {
        webView?.evaluateJavaScript(PageEnhancementScripts.readerFontSize(size), completionHandler: nil)
    }

    var isShowingPDF: Bool {
        guard let url = navigation.url else { return false }
        if url.pathExtension.lowercased() == "pdf" { return true }
        return webView?.url?.pathExtension.lowercased() == "pdf"
    }

    func goBack() {
        // Start page is an app overlay — back returns to the live WKWebView page if any.
        if isShowingStartPage {
            if let webURL = webView?.url, !URLParser.isStartPage(webURL) {
                var next = navigation
                next.lastErrorMessage = nil
                next.url = webURL
                next.title = webView?.title ?? webURL.host ?? BrowserConstants.productName
                next.syncAddressBarFromURL()
                navigation = next
                refreshNavigationChrome()
                return
            }
        }

        guard let webView, webView.canGoBack else {
            refreshNavigationChrome()
            return
        }
        webView.goBack()
        // Chrome flags update via KVO / didCommit; sync once now for snappier buttons.
        refreshNavigationChrome()
    }

    func goForward() {
        guard let webView, webView.canGoForward else {
            refreshNavigationChrome()
            return
        }
        // Leaving start page via forward isn't typical; if web can go forward, show web content.
        if isShowingStartPage, let webURL = webView.url {
            var next = navigation
            next.url = webURL
            next.syncAddressBarFromURL()
            navigation = next
        }
        webView.goForward()
        refreshNavigationChrome()
    }

    func reload() {
        if isShowingStartPage { return }
        if navigation.lastErrorMessage != nil, let url = navigation.url {
            load(url)
            return
        }
        webView?.reload()
    }

    func stopLoading() {
        webView?.stopLoading()
        navigation.isLoading = false
    }

    func goHome() {
        load(URLParser.startPageURL)
    }

    func openProductSite() {
        load(BrowserConstants.productWebsiteURL)
    }

    func openPublisherSite() {
        load(BrowserConstants.publisherURL)
    }

    func toggleDesktopSite() {
        requestsDesktopSite.toggle()
        applyUserAgent(for: navigation.url)
        if !isShowingStartPage {
            webView?.reload()
        }
    }

    func toggleJavaScript() {
        javaScriptEnabled.toggle()
        applyJavaScriptPreference()
        if !isShowingStartPage {
            webView?.reload()
        }
    }

    func setJavaScriptEnabled(_ enabled: Bool) {
        guard javaScriptEnabled != enabled else { return }
        javaScriptEnabled = enabled
        applyJavaScriptPreference()
        if !isShowingStartPage {
            webView?.reload()
        }
    }

    func findInPage(_ query: String, forward: Bool = true) {
        guard !query.isEmpty else {
            clearFindInPage()
            return
        }
        let config = WKFindConfiguration()
        config.backwards = !forward
        config.caseSensitive = false
        config.wraps = true
        webView?.find(query, configuration: config) { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                self.findMatchFound = result.matchFound
                if !result.matchFound {
                    self.findMatchCount = 0
                }
            }
        }
        webView?.evaluateJavaScript(PageEnhancementScripts.countTextMatches(query)) { [weak self] value, _ in
            Task { @MainActor in
                guard let self else { return }
                if let number = value as? Int {
                    self.findMatchCount = number
                } else if let number = value as? Double {
                    self.findMatchCount = Int(number)
                } else if let number = value as? NSNumber {
                    self.findMatchCount = number.intValue
                }
            }
        }
    }

    func clearFindInPage() {
        findMatchCount = nil
        findMatchFound = false
        let config = WKFindConfiguration()
        webView?.find("", configuration: config) { _ in }
    }

    func zoomIn() {
        setZoom(zoomFactor + 0.1)
    }

    func zoomOut() {
        setZoom(zoomFactor - 0.1)
    }

    func resetZoom() {
        setZoom(1.0)
    }

    func setZoom(_ factor: Double) {
        applyZoomValue(factor, persist: true)
    }

    private func applyZoomValue(_ factor: Double, persist: Bool) {
        zoomFactor = min(3.0, max(0.5, (factor * 10).rounded() / 10))
        #if os(macOS)
        webView?.pageZoom = zoomFactor
        #endif
        webView?.evaluateJavaScript(PageEnhancementScripts.setZoom(zoomFactor), completionHandler: nil)
        if persist {
            onZoomChanged?(navigation.url?.host, zoomFactor)
        }
    }

    func applyPageEnhancementsAfterLoad() {
        let host = navigation.url?.host
        if let provider = siteZoomProvider {
            let desired = provider(host)
            if abs(desired - zoomFactor) > 0.01 {
                applyZoomValue(desired, persist: false)
            }
        }
        #if os(macOS)
        webView?.pageZoom = zoomFactor
        #endif
        if zoomFactor != 1.0 {
            webView?.evaluateJavaScript(PageEnhancementScripts.setZoom(zoomFactor), completionHandler: nil)
        }
        if forceDarkEnabled {
            webView?.evaluateJavaScript(PageEnhancementScripts.enableForceDark, completionHandler: nil)
        }
        if lucidModeEnabled {
            webView?.evaluateJavaScript(PageEnhancementScripts.enableLucidMode, completionHandler: nil)
        }
        if isMediaMuted {
            webView?.evaluateJavaScript(PageEnhancementScripts.enableMediaMute, completionHandler: nil)
        }
        if isFocusMode {
            applyFocusMode()
        }
        onPageEnhanced?(self)
    }

    func toggleMediaMute() {
        setMediaMuted(!isMediaMuted)
    }

    func setMediaMuted(_ muted: Bool) {
        isMediaMuted = muted
        guard !isShowingStartPage else { return }
        let script = muted
            ? PageEnhancementScripts.enableMediaMute
            : PageEnhancementScripts.disableMediaMute
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func toggleFocusMode() {
        isFocusMode.toggle()
        applyFocusMode()
    }

    func applyFocusMode() {
        guard !isShowingStartPage else { return }
        let script = isFocusMode
            ? PageEnhancementScripts.enableFocusMode
            : PageEnhancementScripts.disableFocusMode
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func toggleForceDark() {
        forceDarkEnabled.toggle()
        let script = forceDarkEnabled
            ? PageEnhancementScripts.enableForceDark
            : PageEnhancementScripts.disableForceDark
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    func setLucidMode(_ enabled: Bool) {
        lucidModeEnabled = enabled
        let script = enabled
            ? PageEnhancementScripts.enableLucidMode
            : PageEnhancementScripts.disableLucidMode
        webView?.evaluateJavaScript(script, completionHandler: nil)
    }

    /// Apply Settings engine preference (Classic and Pulse) and refresh the live UA.
    func applyPreferredEngine(_ engine: BrowserEngineKind) {
        // Skip no-op writes — repeated `@Observable` publishes during navigation can crash SwiftUI.
        guard preferredEngine != engine else {
            applyUserAgent()
            return
        }
        preferredEngine = engine
        applyUserAgent()
    }

    func clearEngineOverride() {
        engineOverride = nil
        onResolveEngine?(self, navigation.url)
        applyUserAgent()
    }

    func setEngineOverride(_ engine: BrowserEngineKind?) {
        engineOverride = engine
        onResolveEngine?(self, navigation.url)
        applyUserAgent()
    }

    func toggleReaderMode() {
        guard !isShowingStartPage else { return }
        webView?.evaluateJavaScript(PageEnhancementScripts.readerMode) { [weak self] result, _ in
            Task { @MainActor in
                guard let self else { return }
                if let status = result as? String {
                    self.isReaderMode = (status == "on")
                } else {
                    self.isReaderMode.toggle()
                }
            }
        }
    }

    func printPage() {
        guard let webView, !isShowingStartPage else { return }
        #if os(iOS)
        let controller = UIPrintInteractionController.shared
        let info = UIPrintInfo.printInfo()
        info.jobName = displayTitle
        info.outputType = .general
        controller.printInfo = info
        controller.printFormatter = webView.viewPrintFormatter()
        controller.present(animated: true)
        #elseif os(macOS)
        let info = NSPrintInfo.shared
        let operation = webView.printOperation(with: info)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
        #endif
    }

    /// Capture a bitmap of the visible page (for Share / Save).
    #if os(iOS)
    func captureScreenshot() async -> UIImage? {
        guard let webView, !isShowingStartPage else { return nil }
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    #elseif os(macOS)
    func captureScreenshot() async -> NSImage? {
        guard let webView, !isShowingStartPage else { return nil }
        return await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }
    #endif

    /// Create a PDF of the current page.
    func capturePDF() async -> Data? {
        guard let webView, !isShowingStartPage else { return nil }
        return await withCheckedContinuation { continuation in
            webView.createPDF { result in
                switch result {
                case .success(let data):
                    continuation.resume(returning: data)
                case .failure:
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Call after WebKit navigation changes so toolbar buttons stay accurate.
    func refreshNavigationChrome() {
        let web = webView
        var next = navigation
        if isShowingStartPage {
            // From start page, Back is available when a real page is still loaded underneath.
            let hasUnderlyingPage: Bool = {
                guard let url = web?.url else { return false }
                return !URLParser.isStartPage(url)
            }()
            next.canGoBack = hasUnderlyingPage || (web?.canGoBack ?? false)
            next.canGoForward = web?.canGoForward ?? false
            next.isLoading = false
            next.estimatedProgress = 0
        } else {
            next.canGoBack = web?.canGoBack ?? false
            next.canGoForward = web?.canGoForward ?? false
            if let web {
                next.isLoading = web.isLoading
                next.estimatedProgress = web.estimatedProgress
            }
        }
        // Replace the whole struct so @Observable reliably notifies SwiftUI.
        if next != navigation {
            navigation = next
        }
    }

    private func showStartPagePreservingWebHistory() {
        navigation.isLoading = false
        navigation.estimatedProgress = 0
        navigation.title = BrowserConstants.productName
        navigation.lastErrorMessage = nil
        // Do not ask WKWebView to load oriel:// — keep the previous page in the web view.
        webView?.stopLoading()
        refreshNavigationChrome()
    }

    private func applyUserAgent(for url: URL? = nil) {
        guard let webView else { return }
        let desired = UserAgentPolicy.customUserAgent(
            for: url ?? navigation.url,
            requestsDesktopSite: requestsDesktopSite,
            preferredEngine: preferredEngine
        )
        if webView.customUserAgent != desired {
            webView.customUserAgent = desired
        }
    }

    /// Keeps UA / Smart engine choice in sync for the destination URL of a navigation.
    func syncUserAgentForNavigation(to url: URL?) {
        onResolveEngine?(self, url)
        applyUserAgent(for: url)
    }

    private func applyJavaScriptPreference() {
        webView?.configuration.defaultWebpagePreferences.allowsContentJavaScript = javaScriptEnabled
    }
}
