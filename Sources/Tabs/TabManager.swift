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

    init(searchEngine: SearchEngine = .duckDuckGo, restoring snapshot: SessionSnapshot? = nil) {
        self.searchEngine = searchEngine

        if let snapshot, !snapshot.tabs.isEmpty {
            let restored: [BrowserTab] = snapshot.tabs.compactMap { item in
                guard let url = URL(string: item.urlString) else { return nil }
                // Phase 2: private tabs restored only as normal unless we add private mode UI in Phase 3.
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
                tabs = [makeTab()]
            } else {
                tabs = restored
            }
            if let active = snapshot.activeTabID, tabs.contains(where: { $0.id == active }) {
                activeTabID = active
            } else {
                activeTabID = tabs.first?.id
            }
        } else {
            let tab = makeTab()
            tabs = [tab]
            activeTabID = tab.id
        }

        wireCallbacks()
    }

    @discardableResult
    func createTab(url: URL? = nil, select: Bool = true) -> BrowserTab {
        let tab = makeTab(url: url)
        tabs.append(tab)
        if select {
            activeTabID = tab.id
        }
        notifySessionChanged()
        return tab
    }

    func selectTab(id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeTabID = id
        notifySessionChanged()
    }

    func closeTab(id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let tab = tabs[index]
        closedTabs.insert(
            ClosedTabRecord(
                url: tab.restorableURL,
                title: tab.displayTitle,
                isPrivate: tab.isPrivate,
                searchEngine: tab.searchEngine
            ),
            at: 0
        )
        if closedTabs.count > 20 {
            closedTabs = Array(closedTabs.prefix(20))
        }

        tabs.remove(at: index)
        if tabs.isEmpty {
            let fresh = makeTab()
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
        createTab(url: active.restorableURL, select: true)
    }

    @discardableResult
    func restoreClosedTab() -> BrowserTab? {
        guard let record = closedTabs.first else { return nil }
        closedTabs.removeFirst()
        return createTab(url: record.url, select: true)
    }

    func closeActiveTab() {
        guard let id = activeTabID else { return }
        closeTab(id: id)
    }

    func makeSessionSnapshot() -> SessionSnapshot {
        SessionSnapshot(
            tabs: tabs.map {
                SessionSnapshot.TabSnapshot(
                    id: $0.id,
                    urlString: $0.restorableURL.absoluteString,
                    title: $0.displayTitle,
                    isPrivate: $0.isPrivate
                )
            },
            activeTabID: activeTabID,
            savedAt: .now
        )
    }

    private func makeTab(url: URL? = nil) -> BrowserTab {
        let tab = BrowserTab(isPrivate: false, searchEngine: searchEngine, initialURL: url)
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
