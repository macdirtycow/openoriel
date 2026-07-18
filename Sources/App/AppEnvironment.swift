import Foundation
import Observation
import WebKit
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Composition root for Oriel.
@Observable
@MainActor
final class AppEnvironment {
    let settings: BrowserSettings
    let bookmarks: BookmarkStore
    let history: HistoryStore
    let sessionStore: SessionStore
    let tabs: TabManager
    let privacy: PrivacySettings
    let privacyStats: PrivacyStats
    let contentBlocker: ContentBlockerManager
    let downloads: DownloadManager
    let permissions: WebsitePermissionManager
    let extensions: WebExtensionManager
    let linkQueue: LinkQueueStore
    let searchSuggestions: SearchSuggestionProvider
    let elementHide: ElementHideStore
    let icloudSync: iCloudSyncService
    let profiles: ProfileStore
    let installedWebApps: InstalledWebAppStore
    let workspaces: WorkspaceStore
    let defaultBrowser: DefaultBrowserService

    var showAbout = false
    var showTabOverview = false
    var showBookmarks = false
    var showHistory = false
    var showPrivacyShield = false
    var showDownloads = false
    var showFindInPage = false
    var showSettings = false
    var showExtensions = false
    var showLinkQueue = false
    var showFireButton = false
    var showTranslate = false
    var showProfiles = false
    var showWorkspaces = false
    var showPictureInPicturePicker = false
    var useVerticalTabs = false
    /// When set, content shows this tab beside the active tab.
    var splitTabID: UUID?
    var findQuery = ""
    var authPopup: WebAuthPopupState?

    var activeTab: BrowserTab? { tabs.activeTab }

    var splitTab: BrowserTab? {
        guard let splitTabID else { return nil }
        return tabs.tabs.first { $0.id == splitTabID }
    }

    var isSplitViewActive: Bool { splitTab != nil }

    init(
        settings: BrowserSettings? = nil,
        bookmarks: BookmarkStore? = nil,
        history: HistoryStore? = nil,
        sessionStore: SessionStore? = nil,
        privacy: PrivacySettings? = nil,
        privacyStats: PrivacyStats? = nil,
        contentBlocker: ContentBlockerManager? = nil,
        downloads: DownloadManager? = nil,
        permissions: WebsitePermissionManager? = nil,
        extensions: WebExtensionManager? = nil,
        linkQueue: LinkQueueStore? = nil,
        searchSuggestions: SearchSuggestionProvider? = nil,
        elementHide: ElementHideStore? = nil,
        icloudSync: iCloudSyncService? = nil,
        profiles: ProfileStore? = nil,
        installedWebApps: InstalledWebAppStore? = nil,
        workspaces: WorkspaceStore? = nil,
        defaultBrowser: DefaultBrowserService? = nil
    ) {
        let resolvedSettings = settings ?? BrowserSettings()
        let resolvedBookmarks = bookmarks ?? BookmarkStore()
        let resolvedHistory = history ?? HistoryStore()
        let resolvedSession = sessionStore ?? SessionStore()
        let resolvedPrivacy = privacy ?? PrivacySettings()
        let resolvedStats = privacyStats ?? PrivacyStats()
        let resolvedBlocker = contentBlocker ?? ContentBlockerManager()
        let resolvedDownloads = downloads ?? DownloadManager()
        let resolvedPermissions = permissions ?? WebsitePermissionManager()
        let resolvedExtensions = extensions ?? WebExtensionManager()
        let resolvedLinkQueue = linkQueue ?? LinkQueueStore()

        self.settings = resolvedSettings
        self.bookmarks = resolvedBookmarks
        self.history = resolvedHistory
        self.sessionStore = resolvedSession
        self.privacy = resolvedPrivacy
        self.privacyStats = resolvedStats
        self.contentBlocker = resolvedBlocker
        self.downloads = resolvedDownloads
        self.permissions = resolvedPermissions
        self.extensions = resolvedExtensions
        self.linkQueue = resolvedLinkQueue
        self.searchSuggestions = searchSuggestions ?? SearchSuggestionProvider()
        self.elementHide = elementHide ?? ElementHideStore()
        self.icloudSync = icloudSync ?? iCloudSyncService()
        self.profiles = profiles ?? ProfileStore()
        self.installedWebApps = installedWebApps ?? InstalledWebAppStore()
        self.workspaces = workspaces ?? WorkspaceStore()
        self.defaultBrowser = defaultBrowser ?? DefaultBrowserService()
        resolvedSession.restorePreviousSession = resolvedSettings.restorePreviousSession

        let snapshot = resolvedSession.load()
        let manager = TabManager(searchEngine: resolvedSettings.searchEngine, restoring: snapshot)
        self.tabs = manager
        manager.javaScriptEnabledProvider = { [weak self] in
            self?.settings.javaScriptEnabledByDefault ?? true
        }
        // Restored tabs were created before the provider existed — apply the real default now.
        let jsDefault = resolvedSettings.javaScriptEnabledByDefault
        for tab in manager.tabs {
            tab.javaScriptEnabled = jsDefault
        }
        manager.homepageProvider = { [weak self] in
            guard let self else { return nil }
            switch self.settings.newTabBehavior {
            case .startPage: return nil
            case .homepage: return self.settings.homepageURL
            }
        }

        manager.onTabFinishedNavigation = { [weak self] tab in
            guard let self else { return }
            guard !tab.isPrivate else { return }
            guard let url = tab.navigation.url else { return }
            self.history.record(title: tab.navigation.title, url: url)
        }
        manager.onSessionChanged = { [weak self] in
            self?.wireTabPrivacyHooks()
            self?.persistSession()
            self?.icloudSync.noteSessionChange()
            if let split = self?.splitTabID, self?.tabs.tabs.contains(where: { $0.id == split }) != true {
                self?.splitTabID = nil
            }
        }

        wireTabPrivacyHooks()
        persistSession()
        resolvedBookmarks.onDidChange = { [weak self] in
            self?.icloudSync.noteLocalChange()
        }
        resolvedLinkQueue.onDidChange = { [weak self] in
            self?.icloudSync.noteLocalChange()
        }
        resolvedHistory.onDidChange = { [weak self] in
            self?.icloudSync.noteLocalChange()
        }
        self.icloudSync.attach(
            bookmarks: resolvedBookmarks,
            settings: resolvedSettings,
            linkQueue: resolvedLinkQueue,
            history: resolvedHistory,
            sessionProvider: { [weak self] in
                self?.tabs.makeSessionSnapshot() ?? SessionSnapshot(tabs: [], activeTabID: nil, savedAt: .now)
            },
            onRemoteSessionNewer: { [weak self] remote in
                guard let self else { return }
                // Keep remote tabs available; only auto-merge when this device has a single empty start tab.
                let local = self.tabs.makeSessionSnapshot()
                let onlyStart = local.tabs.count <= 1
                    && local.tabs.allSatisfy { URLParser.isStartPage(URL(string: $0.urlString)) }
                if onlyStart, !remote.tabs.isEmpty {
                    self.tabs.replaceNormalTabs(from: remote)
                    self.wireTabPrivacyHooks()
                    self.persistSession()
                }
            }
        )
        self.useVerticalTabs = UserDefaults.standard.bool(forKey: "oriel.verticalTabs")

        Task { await resolvedBlocker.prepare() }
    }

    func persistSession() {
        let snapshot = tabs.makeSessionSnapshot()
        sessionStore.save(snapshot)
        workspaces.saveActiveSnapshot(snapshot)
    }

    func switchWorkspace(id: UUID) {
        guard let next = workspaces.select(id: id, savingCurrent: tabs.makeSessionSnapshot()) else { return }
        splitTabID = nil
        tabs.replaceNormalTabs(from: next)
        wireTabPrivacyHooks()
        persistSession()
        icloudSync.noteSessionChange()
    }

    func openSplitView(with tabID: UUID? = nil) {
        if let tabID, tabs.tabs.contains(where: { $0.id == tabID }), tabID != tabs.activeTabID {
            splitTabID = tabID
            return
        }
        let side = tabs.createTab(select: false)
        wireTabPrivacyHooks(for: side)
        splitTabID = side.id
    }

    func closeSplitView() {
        splitTabID = nil
    }

    func focusSplitPane(isSecondary: Bool) {
        if isSecondary, let splitTabID {
            tabs.selectTab(id: splitTabID)
        }
    }

    func applyRemoteSession(_ snapshot: SessionSnapshot) {
        tabs.replaceNormalTabs(from: snapshot)
        wireTabPrivacyHooks()
        persistSession()
        icloudSync.noteSessionChange()
    }

    func bookmarkActivePage() {
        guard let tab = activeTab,
              let url = tab.navigation.url,
              !URLParser.isStartPage(url) else { return }
        bookmarks.add(title: tab.displayTitle, url: url)
    }

    func openURLInNewTab(_ url: URL, isPrivate: Bool = false) {
        tabs.createTab(url: url, isPrivate: isPrivate, select: true)
        wireTabPrivacyHooks()
    }

    /// Opens an http/https link handed to Oriel as the system browser (or via Share).
    func handleIncomingURL(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return }
        if let tab = activeTab, tab.isShowingStartPage {
            tab.load(url)
            wireTabPrivacyHooks()
        } else {
            openURLInNewTab(url)
        }
    }

    func contentBlockingEnabled(for tab: BrowserTab) -> Bool {
        privacy.effectiveContentBlocking(forHost: tab.navigation.url?.host)
    }

    func performFind(forward: Bool = true) {
        guard let tab = activeTab else { return }
        tab.findInPage(findQuery, forward: forward)
    }

    func closeFind() {
        showFindInPage = false
        findQuery = ""
        activeTab?.clearFindInPage()
    }

    func setSearchEngine(_ engine: SearchEngine) {
        settings.searchEngine = engine
        tabs.searchEngine = engine
        for tab in tabs.tabs {
            tab.searchEngine = engine
        }
        icloudSync.noteLocalChange()
    }

    /// Switch cookie jar and remount every non-private tab onto the active profile store.
    func applyProfile(id: UUID) {
        profiles.select(id: id)
        for tab in tabs.tabs where !tab.isPrivate {
            let url = tab.restorableURL
            tab.webView = nil
            if !URLParser.isStartPage(url) {
                tab.load(url)
            }
        }
        wireTabPrivacyHooks()
        persistSession()
    }

    func copyCurrentURL() {
        guard let url = activeTab?.navigation.url,
              !URLParser.isStartPage(url) else { return }
        #if os(iOS)
        UIPasteboard.general.string = url.absoluteString
        #elseif os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        #endif
    }

    var shareURL: URL? {
        guard let url = activeTab?.navigation.url, !URLParser.isStartPage(url) else { return nil }
        return url
    }

    func presentAuthPopup(_ webView: WKWebView) {
        authPopup = WebAuthPopupState(webView: webView, title: webView.title?.nilIfEmpty ?? "Sign in")
    }

    func updateAuthPopupTitle(_ title: String?) {
        guard let title = title?.nilIfEmpty else { return }
        authPopup?.title = title
    }

    func dismissAuthPopup() {
        authPopup?.webView.stopLoading()
        authPopup = nil
    }

    func wireTabPrivacyHooks(for tab: BrowserTab? = nil) {
        let targets = tab.map { [$0] } ?? tabs.tabs
        for item in targets {
            item.shouldUpgradeHTTPS = { [weak self] url in
                guard let self else { return true }
                return self.privacy.effectiveHTTPSUpgrade(forHost: url.host)
            }
            item.onHTTPSUpgrade = { [weak self] in
                self?.privacyStats.recordHTTPSUpgrade()
            }
            item.shouldStripTracking = { [weak self] in
                self?.settings.stripTrackingParameters ?? true
            }
            item.isHTTPSOnlyMode = { [weak self] in
                self?.privacy.httpsOnlyMode ?? false
            }
            item.elementHideScript = { [weak self] in
                guard let self else { return "" }
                return self.elementHide.injectionScript(forHost: item.navigation.url?.host)
            }
        }
    }

    func enqueueLinkForLater(title: String? = nil, url: URL) {
        let resolvedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        linkQueue.enqueue(
            title: (resolvedTitle?.isEmpty == false ? resolvedTitle! : (url.host ?? url.absoluteString)),
            url: url
        )
        showLinkQueue = true
    }

    func enqueueCurrentPageForLater() {
        guard let tab = activeTab,
              let url = tab.navigation.url,
              !URLParser.isStartPage(url) else { return }
        enqueueLinkForLater(title: tab.displayTitle, url: url)
    }

    func setVerticalTabsEnabled(_ enabled: Bool) {
        useVerticalTabs = enabled
        UserDefaults.standard.set(enabled, forKey: "oriel.verticalTabs")
    }

    func autofillPasswordForActivePage() async {
        guard let tab = activeTab,
              let url = tab.navigation.url,
              !URLParser.isStartPage(url),
              let credential = await PasswordAutofillService.requestCredentials(for: url),
              let webView = tab.webView else { return }
        let user = credential.user.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let pass = credential.password.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function(){
          var user = document.querySelector('input[type=email],input[type=text],input[name*=user i],input[name*=email i],input[autocomplete=username]');
          var pass = document.querySelector('input[type=password]');
          if (user) { user.focus(); user.value = '\(user)'; user.dispatchEvent(new Event('input',{bubbles:true})); }
          if (pass) { pass.focus(); pass.value = '\(pass)'; pass.dispatchEvent(new Event('input',{bubbles:true})); }
          return !!(user || pass);
        })();
        """
        webView.evaluateJavaScript(script, in: nil, in: .page) { _ in }
        icloudSync.pushAll()
    }

    func installCurrentPageAsWebApp() async {
        guard let tab = activeTab,
              let url = tab.navigation.url,
              !URLParser.isStartPage(url),
              let webView = tab.webView else { return }
        let value: Any? = await withCheckedContinuation { cont in
            webView.evaluateJavaScript(ProgressiveWebAppDetector.detectScript, in: nil, in: .page) { result in
                switch result {
                case .success(let v): cont.resume(returning: v)
                case .failure: cont.resume(returning: nil)
                }
            }
        }
        let info = ProgressiveWebAppDetector.parseDetectResult(value, pageURL: url)
            ?? ProgressiveWebAppInfo(name: tab.displayTitle, startURL: url, manifestURL: nil, iconURL: nil)
        installedWebApps.install(info)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
