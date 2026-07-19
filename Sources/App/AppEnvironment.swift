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
    let extensionThemes: ExtensionThemeStore
    let linkQueue: LinkQueueStore
    let searchSuggestions: SearchSuggestionProvider
    let elementHide: ElementHideStore
    let icloudSync: iCloudSyncService
    let profiles: ProfileStore
    let installedWebApps: InstalledWebAppStore
    let workspaces: WorkspaceStore
    let defaultBrowser: DefaultBrowserService
    let appIcon: AppIconService
    let pulseAmbience: PulseAmbiencePlayer

    var showAbout = false
    var showTabOverview = false
    var showBookmarks = false
    var showHistory = false
    var showPrivacyShield = false
    var showDownloads = false
    var showFindInPage = false
    var showSettings = false
    var showExtensions = false
    /// Native phone-readable Chrome/Firefox catalog (avoids broken desktop CWS layout).
    var showOrielStore = false
    /// Alert when the user opens chromewebstore.google.com or addons.mozilla.org in a tab.
    var showOrielStoreTip = false
    /// Hosts already tipped this session (“Keep browsing” / opened Oriel Store).
    private(set) var orielStoreTipSeenHosts: Set<String> = []
    var showLinkQueue = false
    var showFireButton = false
    var showTranslate = false
    var showProfiles = false
    var showWorkspaces = false
    var showPictureInPicturePicker = false
    var showPulsePerformance = false
    /// Compact Pulse Corner overlay (GX-style control strip).
    var showPulseCorner = false
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
        extensionThemes: ExtensionThemeStore? = nil,
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
        let resolvedThemes = extensionThemes ?? ExtensionThemeStore()
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
        self.extensionThemes = resolvedThemes
        self.linkQueue = resolvedLinkQueue
        resolvedThemes.attach(settings: resolvedSettings)
        resolvedExtensions.themeStore = resolvedThemes
        self.searchSuggestions = searchSuggestions ?? SearchSuggestionProvider()
        self.elementHide = elementHide ?? ElementHideStore()
        self.icloudSync = icloudSync ?? iCloudSyncService()
        self.profiles = profiles ?? ProfileStore()
        self.installedWebApps = installedWebApps ?? InstalledWebAppStore()
        self.workspaces = workspaces ?? WorkspaceStore()
        self.defaultBrowser = defaultBrowser ?? DefaultBrowserService()
        self.appIcon = AppIconService()
        self.pulseAmbience = PulseAmbiencePlayer()
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
            self?.persistSession() // debounced
            self?.icloudSync.noteSessionChange()
            if let split = self?.splitTabID, self?.tabs.tabs.contains(where: { $0.id == split }) != true {
                self?.splitTabID = nil
            }
        }

        wireTabPrivacyHooks()
        persistSessionNow()
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
                    self.persistSessionNow()
                }
            }
        )
        self.useVerticalTabs = UserDefaults.standard.bool(forKey: "oriel.verticalTabs")

        Task {
            await resolvedBlocker.prepare()
            syncPulseRuntimeFlags()
        }
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.powerStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.syncPulseRuntimeFlags()
            }
        }
        if resolvedSettings.edition.isPulse, resolvedSettings.pulseCornerEnabled {
            showPulseCorner = true
        }
        Task { await self.appIcon.applyForEdition(resolvedSettings.edition) }
    }

    /// Keep Data Saver / WebView pool / corner visibility aligned with Pulse + battery state.
    func syncPulseRuntimeFlags() {
        settings.refreshPulsePoolLimitPublic()
        contentBlocker.setDataSaverEnabled(settings.effectiveDataSaver)
        if settings.edition.isPulse, settings.pulseCornerEnabled {
            // Don't auto-open over sheets; only ensure flag can be used.
        } else {
            showPulseCorner = false
            if !settings.edition.isPulse {
                pulseAmbience.stop()
            }
        }
    }

    func selectBrowserEdition(_ edition: BrowserEdition, applySuggestedLook: Bool) {
        settings.selectEdition(edition, applySuggestedLook: applySuggestedLook)
        showPulseCorner = edition.isPulse && settings.pulseCornerEnabled
        syncPulseRuntimeFlags()
        Task { await appIcon.applyForEdition(edition) }
        icloudSync.noteLocalChange()
    }

    func applyWorkspacePreset(_ preset: WorkspacePreset) {
        if preset.prefersPulse {
            settings.selectEdition(.pulse, applySuggestedLook: true)
            showPulseCorner = settings.pulseCornerEnabled
        }
        settings.pulseWebViewLimit = preset.webViewLimit
        settings.pulseDataSaver = preset.dataSaver
        settings.pulseAggressiveTabUnload = true
        #if os(macOS)
        setVerticalTabsEnabled(preset.verticalTabs)
        #endif
        Task { await appIcon.applyForEdition(settings.edition) }

        let urls = preset.seedURLs
        var snapshots: [SessionSnapshot.TabSnapshot] = []
        for url in urls {
            snapshots.append(
                SessionSnapshot.TabSnapshot(
                    id: UUID(),
                    urlString: url.absoluteString,
                    title: url.host ?? preset.displayName,
                    isPrivate: false,
                    isPinned: false
                )
            )
        }
        let seed = SessionSnapshot(
            tabs: snapshots,
            activeTabID: snapshots.first?.id,
            groups: [],
            savedAt: .now
        )
        let created = workspaces.create(name: preset.displayName, snapshot: seed)
        switchWorkspace(id: created.id)
        syncPulseRuntimeFlags()
        icloudSync.noteLocalChange()
    }

    private var sessionPersistTask: Task<Void, Never>?

    /// Coalesces rapid tab churn (open/close/select) into one disk write.
    func persistSession() {
        sessionPersistTask?.cancel()
        sessionPersistTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            persistSessionNow()
        }
    }

    func persistSessionNow() {
        sessionPersistTask?.cancel()
        sessionPersistTask = nil
        let snapshot = tabs.makeSessionSnapshot()
        sessionStore.save(snapshot)
        workspaces.saveActiveSnapshot(snapshot)
    }

    func flushPendingPersistence() {
        persistSessionNow()
        privacyStats.flush()
    }

    func switchWorkspace(id: UUID) {
        guard let next = workspaces.select(id: id, savingCurrent: tabs.makeSessionSnapshot()) else { return }
        splitTabID = nil
        tabs.replaceNormalTabs(from: next)
        wireTabPrivacyHooks()
        persistSessionNow()
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
        considerOrielStoreTip(for: url)
    }

    /// Offer Oriel Store when the user lands on Chrome Web Store or Firefox AMO in a tab.
    func considerOrielStoreTip(for url: URL?) {
        guard !showOrielStore else { return }
        guard UserAgentPolicy.isExtensionStoreURL(url),
              let host = url?.host?.lowercased(), !host.isEmpty else { return }
        // One tip per store host per app session.
        guard !orielStoreTipSeenHosts.contains(host) else { return }
        orielStoreTipSeenHosts.insert(host)
        showOrielStoreTip = true
    }

    func dismissOrielStoreTip(openStore: Bool) {
        showOrielStoreTip = false
        if openStore {
            showOrielStore = true
        }
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
        WebViewPool.shared.releaseAll { tabID in
            tabs.tabs.contains { $0.id == tabID && !$0.isPrivate }
        }
        for tab in tabs.tabs where !tab.isPrivate {
            let url = tab.restorableURL
            tab.webView = nil
            if !URLParser.isStartPage(url) {
                tab.load(url)
            }
        }
        wireTabPrivacyHooks()
        persistSessionNow()
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
        // Prefer JSON encoding so quotes/newlines in passwords cannot break the script.
        guard
            let userData = try? JSONEncoder().encode(credential.user),
            let passData = try? JSONEncoder().encode(credential.password),
            let userJSON = String(data: userData, encoding: .utf8),
            let passJSON = String(data: passData, encoding: .utf8)
        else { return }
        let script = """
        (function(){
          var userValue = \(userJSON);
          var passValue = \(passJSON);
          function setValue(el, value) {
            if (!el) return false;
            el.focus();
            var proto = window.HTMLInputElement && HTMLInputElement.prototype;
            var desc = proto && Object.getOwnPropertyDescriptor(proto, 'value');
            if (desc && desc.set) { desc.set.call(el, value); }
            else { el.value = value; }
            el.dispatchEvent(new Event('input', { bubbles: true }));
            el.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }
          var form = document.querySelector('form');
          var scope = form || document;
          var user = scope.querySelector('input[autocomplete="username"],input[autocomplete="email"],input[type="email"],input[name*="user" i],input[name*="email" i],input[id*="user" i],input[id*="email" i],input[type="text"]');
          var pass = scope.querySelector('input[type="password"],input[autocomplete="current-password"],input[autocomplete="new-password"]');
          var filledUser = setValue(user, userValue);
          var filledPass = setValue(pass, passValue);
          if (filledPass && pass) pass.focus();
          else if (filledUser && user) user.focus();
          return filledUser || filledPass;
        })();
        """
        webView.evaluateJavaScript(script, in: nil, in: .page) { _ in }
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
