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

    var showAbout = false
    var showTabOverview = false
    var showBookmarks = false
    var showHistory = false

    var activeTab: BrowserTab? { tabs.activeTab }

    init(
        settings: BrowserSettings? = nil,
        bookmarks: BookmarkStore? = nil,
        history: HistoryStore? = nil,
        sessionStore: SessionStore? = nil
    ) {
        let resolvedSettings = settings ?? BrowserSettings()
        let resolvedBookmarks = bookmarks ?? BookmarkStore()
        let resolvedHistory = history ?? HistoryStore()
        let resolvedSession = sessionStore ?? SessionStore()

        self.settings = resolvedSettings
        self.bookmarks = resolvedBookmarks
        self.history = resolvedHistory
        self.sessionStore = resolvedSession
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
            self?.persistSession()
        }

        // Persist initial restored/created session.
        persistSession()
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

    func openURLInNewTab(_ url: URL) {
        tabs.createTab(url: url, select: true)
    }
}
