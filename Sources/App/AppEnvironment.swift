import Foundation
import Observation

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

    var showAbout = false
    var showTabOverview = false
    var showBookmarks = false
    var showHistory = false
    var showPrivacyShield = false
    var showDownloads = false
    var showFindInPage = false
    var findQuery = ""

    var activeTab: BrowserTab? { tabs.activeTab }

    init(
        settings: BrowserSettings? = nil,
        bookmarks: BookmarkStore? = nil,
        history: HistoryStore? = nil,
        sessionStore: SessionStore? = nil,
        privacy: PrivacySettings? = nil,
        privacyStats: PrivacyStats? = nil,
        contentBlocker: ContentBlockerManager? = nil,
        downloads: DownloadManager? = nil,
        permissions: WebsitePermissionManager? = nil
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

        self.settings = resolvedSettings
        self.bookmarks = resolvedBookmarks
        self.history = resolvedHistory
        self.sessionStore = resolvedSession
        self.privacy = resolvedPrivacy
        self.privacyStats = resolvedStats
        self.contentBlocker = resolvedBlocker
        self.downloads = resolvedDownloads
        self.permissions = resolvedPermissions
        resolvedSession.restorePreviousSession = resolvedSettings.restorePreviousSession

        let snapshot = resolvedSession.load()
        let manager = TabManager(searchEngine: resolvedSettings.searchEngine, restoring: snapshot)
        self.tabs = manager

        manager.onTabFinishedNavigation = { [weak self] tab in
            guard let self else { return }
            guard !tab.isPrivate else { return }
            guard let url = tab.navigation.url else { return }
            self.history.record(title: tab.navigation.title, url: url)
        }
        manager.onSessionChanged = { [weak self] in
            self?.wireTabPrivacyHooks()
            self?.persistSession()
        }

        wireTabPrivacyHooks()
        persistSession()

        Task { await resolvedBlocker.prepare() }
    }

    func persistSession() {
        sessionStore.save(tabs.makeSessionSnapshot())
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
        }
    }
}
