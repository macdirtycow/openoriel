import Foundation
import Observation

struct ClosedTabRecord: Equatable {
    let url: URL
    let title: String
    let isPrivate: Bool
    let searchEngine: SearchEngine
}

@Observable
@MainActor
final class TabManager {
    private(set) var tabs: [BrowserTab] = []
    private(set) var activeTabID: UUID?
    private(set) var closedTabs: [ClosedTabRecord] = []

    var searchEngine: SearchEngine
    var onTabFinishedNavigation: ((BrowserTab) -> Void)?
    var onSessionChanged: (() -> Void)?

    var activeTab: BrowserTab? {
        guard let activeTabID else { return tabs.first }
        return tabs.first { $0.id == activeTabID } ?? tabs.first
    }

    var canRestoreClosedTab: Bool { !closedTabs.isEmpty }

    var normalTabs: [BrowserTab] { tabs.filter { !$0.isPrivate } }
    var privateTabs: [BrowserTab] { tabs.filter(\.isPrivate) }

    init(searchEngine: SearchEngine = .duckDuckGo, restoring snapshot: SessionSnapshot? = nil) {
        self.searchEngine = searchEngine

        if let snapshot, !snapshot.tabs.isEmpty {
            // Never restore private tabs from disk.
            let restored: [BrowserTab] = snapshot.tabs.compactMap { item in
                guard !item.isPrivate else { return nil }
                guard let url = URL(string: item.urlString) else { return nil }
                let tab = BrowserTab(
                    id: item.id,
                    isPrivate: false,
                    searchEngine: searchEngine,
                    initialURL: url
                )
                tab.navigation.title = item.title
                return tab
            }
            if restored.isEmpty {
                tabs = [makeTab(isPrivate: false)]
            } else {
                tabs = restored
            }
            if let active = snapshot.activeTabID, tabs.contains(where: { $0.id == active }) {
                activeTabID = active
            } else {
                activeTabID = tabs.first?.id
            }
        } else {
            let tab = makeTab(isPrivate: false)
            tabs = [tab]
            activeTabID = tab.id
        }

        wireCallbacks()
    }

    @discardableResult
    func createTab(url: URL? = nil, isPrivate: Bool = false, select: Bool = true) -> BrowserTab {
        let initial: URL?
        if let url {
            initial = url
        } else if !isPrivate, let homepageProvider {
            initial = homepageProvider()
        } else {
            initial = nil
        }
        let tab = makeTab(url: initial, isPrivate: isPrivate)
        tabs.append(tab)
        if select {
            activeTabID = tab.id
        }
        notifySessionChanged()
        return tab
    }

    /// Optional homepage for new normal tabs (start page when nil).
    var homepageProvider: (() -> URL?)?

    @discardableResult
    func createPrivateTab(select: Bool = true) -> BrowserTab {
        createTab(isPrivate: true, select: select)
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        notifySessionChanged()
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        // Don't keep private closed tabs in the reopen stack (avoids leaking private URLs).
        if !tab.isPrivate {
            closedTabs.insert(
                ClosedTabRecord(
                    url: tab.restorableURL,
                    title: tab.displayTitle,
                    isPrivate: false,
                    searchEngine: tab.searchEngine
                ),
                at: 0
            )
            if closedTabs.count > 20 {
                closedTabs = Array(closedTabs.prefix(20))
            }
        }

        tabs.remove(at: index)
        if tabs.isEmpty {
            let fresh = makeTab(isPrivate: false)
            tabs = [fresh]
            activeTabID = fresh.id
        } else if activeTabID == id {
            let newIndex = min(index, tabs.count - 1)
            activeTabID = tabs[newIndex].id
        }
        notifySessionChanged()
    }

    func duplicateActiveTab() {
        guard let active = activeTab else { return }
        createTab(url: active.restorableURL, isPrivate: active.isPrivate, select: true)
    }

    @discardableResult
    func restoreClosedTab() -> BrowserTab? {
        guard let record = closedTabs.first else { return nil }
        closedTabs.removeFirst()
        return createTab(url: record.url, isPrivate: false, select: true)
    }

    func closeActiveTab() {
        guard let id = activeTabID else { return }
        closeTab(id: id)
    }

    func makeSessionSnapshot() -> SessionSnapshot {
        // Persist only normal tabs.
        let normal = tabs.filter { !$0.isPrivate }
        let activeNormalID: UUID? = {
            if let active = activeTab, !active.isPrivate { return active.id }
            return normal.first?.id
        }()
        return SessionSnapshot(
            tabs: normal.map {
                SessionSnapshot.TabSnapshot(
                    id: $0.id,
                    urlString: $0.restorableURL.absoluteString,
                    title: $0.displayTitle,
                    isPrivate: false
                )
            },
            activeTabID: activeNormalID,
            savedAt: .now
        )
    }

    private func makeTab(url: URL? = nil, isPrivate: Bool = false) -> BrowserTab {
        let tab = BrowserTab(isPrivate: isPrivate, searchEngine: searchEngine, initialURL: url)
        tab.onNavigationFinished = { [weak self] finished in
            self?.onTabFinishedNavigation?(finished)
            self?.notifySessionChanged()
        }
        return tab
    }

    private func wireCallbacks() {
        for tab in tabs {
            tab.onNavigationFinished = { [weak self] finished in
                self?.onTabFinishedNavigation?(finished)
                self?.notifySessionChanged()
            }
        }
    }

    private func notifySessionChanged() {
        onSessionChanged?()
    }
}
