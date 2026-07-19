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
    private(set) var groups: [TabGroup] = []

    var searchEngine: SearchEngine
    var onTabFinishedNavigation: ((BrowserTab) -> Void)?
    var onSessionChanged: (() -> Void)?
    /// Supplies the default JavaScript preference for newly created tabs.
    var javaScriptEnabledProvider: (() -> Bool)?

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
                tab.javaScriptEnabled = javaScriptEnabledProvider?() ?? true
                tab.isPinned = item.isPinned
                tab.groupID = item.groupID
                tab.navigation.title = item.title
                return tab
            }
            groups = snapshot.groups
            if restored.isEmpty {
                tabs = [makeTab(isPrivate: false)]
            } else {
                tabs = restored
                reorderPinnedFirst()
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

        WebViewPool.shared.release(id)
        tab.webView = nil
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

    /// Restore a specific entry from the Recently Closed list (by stack index).
    @discardableResult
    func restoreClosedTab(at index: Int) -> BrowserTab? {
        guard closedTabs.indices.contains(index) else { return nil }
        let record = closedTabs.remove(at: index)
        return createTab(url: record.url, isPrivate: false, select: true)
    }

    func clearClosedTabs() {
        closedTabs.removeAll()
    }

    /// Close every tab except the given one (pinned tabs are also closed — match Chrome/Safari menus).
    func closeOtherTabs(keeping id: UUID) {
        let ids = tabs.map(\.id).filter { $0 != id }
        for tabID in ids {
            closeTab(id: tabID)
        }
    }

    /// Close tabs to the right of `id` in the current strip order (unpinned + pinned order).
    func closeTabsToTheRight(of id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        let ids = tabs.suffix(from: index + 1).map(\.id)
        for tabID in ids {
            closeTab(id: tabID)
        }
    }

    func closeActiveTab() {
        guard let id = activeTabID else { return }
        closeTab(id: id)
    }

    func togglePin(id: UUID) {
        guard let tab = tabs.first(where: { $0.id == id }) else { return }
        tab.isPinned.toggle()
        reorderPinnedFirst()
        notifySessionChanged()
    }

    func reorderPinnedFirst() {
        let pinned = tabs.filter(\.isPinned)
        let rest = tabs.filter { !$0.isPinned }
        tabs = pinned + rest
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
                    isPrivate: false,
                    isPinned: $0.isPinned,
                    groupID: $0.groupID
                )
            },
            activeTabID: activeNormalID,
            groups: groups,
            savedAt: .now
        )
    }

    /// Replace normal (non-private) tabs from a session snapshot. Keeps private tabs.
    func replaceNormalTabs(from snapshot: SessionSnapshot) {
        let retiringIDs = tabs.filter { !$0.isPrivate }.map(\.id)
        for id in retiringIDs {
            WebViewPool.shared.release(id)
        }
        let privateOnes = tabs.filter(\.isPrivate)
        let restored: [BrowserTab] = snapshot.tabs.compactMap { item in
            guard !item.isPrivate else { return nil }
            guard let url = URL(string: item.urlString) else { return nil }
            let tab = BrowserTab(
                id: item.id,
                isPrivate: false,
                searchEngine: searchEngine,
                initialURL: url
            )
            tab.javaScriptEnabled = javaScriptEnabledProvider?() ?? true
            tab.isPinned = item.isPinned
            tab.groupID = item.groupID
            tab.navigation.title = item.title
            return tab
        }
        groups = snapshot.groups
        if restored.isEmpty {
            tabs = privateOnes.isEmpty ? [makeTab(isPrivate: false)] : privateOnes
            if privateOnes.isEmpty {
                activeTabID = tabs.first?.id
            } else if let active = snapshot.activeTabID, tabs.contains(where: { $0.id == active }) {
                activeTabID = active
            } else {
                activeTabID = tabs.first?.id
            }
        } else {
            tabs = restored + privateOnes
            reorderPinnedFirst()
            if let active = snapshot.activeTabID, tabs.contains(where: { $0.id == active }) {
                activeTabID = active
            } else {
                activeTabID = restored.first?.id
            }
        }
        wireCallbacks()
        notifySessionChanged()
    }

    @discardableResult
    func createGroup(name: String, colorName: String = "teal") -> TabGroup {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let group = TabGroup(
            name: trimmed.isEmpty ? "Group \(groups.count + 1)" : trimmed,
            colorName: colorName
        )
        groups.append(group)
        notifySessionChanged()
        return group
    }

    func renameGroup(id: UUID, name: String) {
        guard let index = groups.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        groups[index].name = trimmed
        notifySessionChanged()
    }

    func deleteGroup(id: UUID) {
        groups.removeAll { $0.id == id }
        for tab in tabs where tab.groupID == id {
            tab.groupID = nil
        }
        notifySessionChanged()
    }

    func assign(tabID: UUID, toGroup groupID: UUID?) {
        guard let tab = tabs.first(where: { $0.id == tabID }) else { return }
        if let groupID {
            guard groups.contains(where: { $0.id == groupID }) else { return }
        }
        tab.groupID = groupID
        notifySessionChanged()
    }

    func closeAllPrivateTabs() {
        let ids = tabs.filter(\.isPrivate).map(\.id)
        for id in ids {
            closeTab(id: id)
        }
    }

    func closeAllTabs(includingPrivate: Bool) {
        let ids = tabs.filter { includingPrivate || !$0.isPrivate }.map(\.id)
        for id in ids {
            closeTab(id: id)
        }
    }


    private func makeTab(url: URL? = nil, isPrivate: Bool = false) -> BrowserTab {
        let tab = BrowserTab(isPrivate: isPrivate, searchEngine: searchEngine, initialURL: url)
        tab.javaScriptEnabled = javaScriptEnabledProvider?() ?? true
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
