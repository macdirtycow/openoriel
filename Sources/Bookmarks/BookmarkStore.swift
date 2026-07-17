import Foundation
import Observation

@Observable
@MainActor
final class BookmarkStore {
    private(set) var bookmarks: [Bookmark] = []
    private let fileName = "bookmarks.json"

    init() {
        load()
    }

    var favorites: [Bookmark] {
        Array(bookmarks.prefix(12))
    }

    func add(title: String, url: URL) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let bookmark = Bookmark(
            title: trimmedTitle.isEmpty ? (url.host ?? url.absoluteString) : trimmedTitle,
            url: url
        )
        // Avoid exact URL duplicates — move existing to front.
        bookmarks.removeAll { $0.urlString == bookmark.urlString }
        bookmarks.insert(bookmark, at: 0)
        persist()
    }

    func update(_ bookmark: Bookmark) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        bookmarks[index] = bookmark
        persist()
    }

    func remove(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        persist()
    }

    func search(_ query: String) -> [Bookmark] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return bookmarks }
        return bookmarks.filter {
            $0.title.lowercased().contains(q) || $0.urlString.lowercased().contains(q)
        }
    }

    func contains(url: URL) -> Bool {
        bookmarks.contains { $0.urlString == url.absoluteString }
    }

    private func load() {
        do {
            if let loaded = try JSONFileStore.load([Bookmark].self, from: fileName) {
                bookmarks = loaded
            }
        } catch {
            bookmarks = []
        }
    }

    private func persist() {
        try? JSONFileStore.save(bookmarks, to: fileName)
    }
}
