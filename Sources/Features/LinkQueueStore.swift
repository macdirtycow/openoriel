import Foundation
import Observation

struct QueuedLink: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var urlString: String
    var createdAt: Date
    /// Reading List: unread until opened.
    var isUnread: Bool
    /// Prefer opening with Reader Mode when supported.
    var openInReader: Bool

    init(
        id: UUID = UUID(),
        title: String,
        url: URL,
        createdAt: Date = Date(),
        isUnread: Bool = true,
        openInReader: Bool = false
    ) {
        self.id = id
        self.title = title.isEmpty ? (url.host ?? url.absoluteString) : title
        self.urlString = url.absoluteString
        self.createdAt = createdAt
        self.isUnread = isUnread
        self.openInReader = openInReader
    }

    var url: URL? { URL(string: urlString) }

    enum CodingKeys: String, CodingKey {
        case id, title, urlString, createdAt, isUnread, openInReader
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        urlString = try c.decode(String.self, forKey: .urlString)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        isUnread = try c.decodeIfPresent(Bool.self, forKey: .isUnread) ?? true
        openInReader = try c.decodeIfPresent(Bool.self, forKey: .openInReader) ?? false
    }
}

@Observable
@MainActor
final class LinkQueueStore {
    private(set) var items: [QueuedLink] = []
    private let fileName = "link-queue.json"
    var onDidChange: (() -> Void)?

    init() {
        if let loaded = try? JSONFileStore.load([QueuedLink].self, from: fileName) {
            items = loaded
        }
    }

    var count: Int { items.count }

    func enqueue(title: String, url: URL, openInReader: Bool = false) {
        guard URLParser.isAllowedNavigation(url), !URLParser.isStartPage(url) else { return }
        if let index = items.firstIndex(where: { $0.urlString == url.absoluteString }) {
            items[index].isUnread = true
            if openInReader { items[index].openInReader = true }
            persist()
            return
        }
        items.insert(QueuedLink(title: title, url: url, openInReader: openInReader), at: 0)
        persist()
    }

    func markRead(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isUnread = false
        persist()
    }

    func toggleReader(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].openInReader.toggle()
        persist()
    }

    var unreadCount: Int { items.filter(\.isUnread).count }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
        persist()
    }

    func replaceAll(_ items: [QueuedLink]) {
        self.items = items
        persist()
    }

    func mergeUnion(_ remote: [QueuedLink]) {
        var map = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        for item in remote {
            if let existing = map[item.id] {
                if item.createdAt > existing.createdAt {
                    map[item.id] = item
                }
            } else if !map.values.contains(where: { $0.urlString == item.urlString }) {
                map[item.id] = item
            }
        }
        items = Array(map.values).sorted { $0.createdAt > $1.createdAt }
        persist()
    }

    func clear() {
        items = []
        persist()
    }

    func consumeAll() -> [QueuedLink] {
        let snapshot = items
        items = []
        persist()
        return snapshot
    }

    private func persist() {
        try? JSONFileStore.save(items, to: fileName)
        onDidChange?()
    }
}
