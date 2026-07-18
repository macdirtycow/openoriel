import Foundation
import Observation

struct QueuedLink: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    var urlString: String
    var createdAt: Date

    init(id: UUID = UUID(), title: String, url: URL, createdAt: Date = Date()) {
        self.id = id
        self.title = title.isEmpty ? (url.host ?? url.absoluteString) : title
        self.urlString = url.absoluteString
        self.createdAt = createdAt
    }

    var url: URL? { URL(string: urlString) }
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

    func enqueue(title: String, url: URL) {
        guard URLParser.isAllowedNavigation(url), !URLParser.isStartPage(url) else { return }
        if items.contains(where: { $0.urlString == url.absoluteString }) { return }
        items.insert(QueuedLink(title: title, url: url), at: 0)
        persist()
    }

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
