import Foundation
import Observation

@Observable
@MainActor
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []
    private let fileName = "bookmarks.json"
    private var tombstones = BookmarkTombstoneStore()
    /// Fired after local mutations so iCloud sync can push.
    var onDidChange: (() -> Void)?

    init() {
        load()
    }

    /// Favorites shown on the start page (explicit pins, else first bookmarks).
    var favorites: [Bookmark] {
        let pinned = bookmarks.filter { !$0.isFolder && $0.isFavorite }
        if !pinned.isEmpty {
            return Array(pinned.prefix(12))
        }
        return Array(bookmarks.filter { !$0.isFolder && $0.parentID == nil }.prefix(12))
    }

    var rootItems: [Bookmark] {
        children(of: nil)
    }

    func children(of parentID: UUID?) -> [Bookmark] {
        bookmarks
            .filter { $0.parentID == parentID }
            .sorted {
                if $0.isFolder != $1.isFolder { return $0.isFolder && !$1.isFolder }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.createdAt < $1.createdAt
            }
    }

    func add(title: String, url: URL, parentID: UUID? = nil) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bookmark = Bookmark(
            title: trimmedTitle.isEmpty ? (url.host ?? url.absoluteString) : trimmedTitle,
            url: url,
            parentID: parentID,
            sortOrder: nextSortOrder(in: parentID)
        )
        bookmarks.removeAll { !$0.isFolder && $0.urlString == bookmark.urlString }
        bookmarks.insert(bookmark, at: 0)
        persist()
    }

    @discardableResult
    func addFolder(title: String, parentID: UUID? = nil) -> Bookmark {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = Bookmark(
            title: trimmed.isEmpty ? "New Folder" : trimmed,
            url: nil,
            parentID: parentID,
            sortOrder: nextSortOrder(in: parentID)
        )
        bookmarks.insert(folder, at: 0)
        persist()
        return folder
    }

    func rename(id: UUID, title: String) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        bookmarks[index].title = trimmed
        persist()
    }

    func move(id: UUID, toParent parentID: UUID?) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }) else { return }
        if let parentID {
            guard bookmarks.contains(where: { $0.id == parentID && $0.isFolder }) else { return }
            // Prevent moving a folder into itself / descendant.
            if isDescendant(id: parentID, of: id) { return }
        }
        bookmarks[index].parentID = parentID
        bookmarks[index].sortOrder = nextSortOrder(in: parentID)
        persist()
    }

    func toggleFavorite(id: UUID) {
        guard let index = bookmarks.firstIndex(where: { $0.id == id }), !bookmarks[index].isFolder else { return }
        bookmarks[index].isFavorite.toggle()
        persist()
    }

    @discardableResult
    func importHTML(_ html: String) -> Int {
        let imported = BookmarkHTMLImporter.parseTree(html)
        var count = 0
        func ingest(_ nodes: [BookmarkHTMLImporter.Node], parentID: UUID?) {
            for node in nodes {
                switch node {
                case .folder(let title, let children):
                    let folder = addFolder(title: title, parentID: parentID)
                    ingest(children, parentID: folder.id)
                case .bookmark(let title, let url):
                    if !contains(url: url) {
                        add(title: title, url: url, parentID: parentID)
                        count += 1
                    }
                }
            }
        }
        ingest(imported, parentID: nil)
        return count
    }

    func exportHTML() -> String {
        BookmarkHTMLExporter.export(items: bookmarks)
    }

    func update(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index] = bookmark
        persist()
    }

    func remove(id: UUID) {
        var toRemove: Set<UUID> = [id]
        var queue = [id]
        while let current = queue.first {
            queue.removeFirst()
            let childIDs = bookmarks.filter { $0.parentID == current }.map(\.id)
            for childID in childIDs where toRemove.insert(childID).inserted {
                queue.append(childID)
            }
        }
        bookmarks.removeAll { toRemove.contains($0.id) }
        tombstones.markDeleted(toRemove)
        persist()
    }

    func search(_ query: String) -> [Bookmark] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let leafs = bookmarks.filter { !$0.isFolder }
        guard !q.isEmpty else { return leafs }
        return leafs.filter {
            $0.title.lowercased().contains(q) || ($0.urlString?.lowercased().contains(q) ?? false)
        }
    }

    func replaceAll(_ items: [Bookmark]) {
        bookmarks = items.filter { !tombstones.contains($0.id) }
        persist()
    }

    /// Merge remote bookmarks without resurrecting locally deleted ones.
    func mergeRemote(_ remote: [Bookmark]) {
        bookmarks = tombstones.merge(local: bookmarks, remote: remote)
        persist()
    }

    func contains(url: URL) -> Bool {
        bookmarks.contains { !$0.isFolder && $0.urlString == url.absoluteString }
    }

    private func nextSortOrder(in parentID: UUID?) -> Int {
        (children(of: parentID).map(\.sortOrder).max() ?? -1) + 1
    }

    private func isDescendant(id: UUID, of ancestorID: UUID) -> Bool {
        var current = bookmarks.first(where: { $0.id == id })?.parentID
        var guardCount = 0
        while let parent = current, guardCount < 64 {
            if parent == ancestorID { return true }
            current = bookmarks.first(where: { $0.id == parent })?.parentID
            guardCount += 1
        }
        return false
    }

    private func load() {
        do {
            if let loaded = try JSONFileStore.load([Bookmark].self, from: fileName) {
                bookmarks = loaded
                return
            }
        } catch {
            bookmarks = []
        }
    }

    private func persist() {
        try? JSONFileStore.save(bookmarks, to: fileName)
        onDidChange?()
    }
}
