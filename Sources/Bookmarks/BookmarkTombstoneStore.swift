import Foundation

/// Deleted bookmark IDs kept so iCloud merge does not resurrect removed bookmarks.
struct BookmarkTombstoneStore {
    private let fileName = "bookmark-tombstones.json"
    private let maxCount = 2000

    private(set) var deletedIDs: [UUID: Date]

    init() {
        if let loaded = try? JSONFileStore.load([String: Double].self, from: fileName) {
            var map: [UUID: Date] = [:]
            for (key, value) in loaded {
                if let id = UUID(uuidString: key) {
                    map[id] = Date(timeIntervalSince1970: value)
                }
            }
            deletedIDs = map
        } else {
            deletedIDs = [:]
        }
    }

    mutating func markDeleted(_ ids: Set<UUID>) {
        let now = Date()
        for id in ids {
            deletedIDs[id] = now
        }
        trim()
        persist()
    }

    mutating func forget(id: UUID) {
        deletedIDs.removeValue(forKey: id)
        persist()
    }

    func contains(_ id: UUID) -> Bool {
        deletedIDs[id] != nil
    }

    /// Merge remote bookmarks while honoring local tombstones.
    func merge(local: [Bookmark], remote: [Bookmark]) -> [Bookmark] {
        var map = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })
        for item in remote {
            if contains(item.id) { continue }
            if let existing = map[item.id] {
                // Prefer newer createdAt as a weak LWW for edits.
                if item.createdAt >= existing.createdAt {
                    map[item.id] = item
                }
            } else {
                map[item.id] = item
            }
        }
        // Drop anything still tombstoned.
        for id in deletedIDs.keys {
            map.removeValue(forKey: id)
        }
        return Array(map.values)
    }

    private mutating func trim() {
        guard deletedIDs.count > maxCount else { return }
        let sorted = deletedIDs.sorted { $0.value < $1.value }
        let drop = sorted.prefix(deletedIDs.count - maxCount)
        for (id, _) in drop {
            deletedIDs.removeValue(forKey: id)
        }
    }

    private func persist() {
        var payload: [String: Double] = [:]
        for (id, date) in deletedIDs {
            payload[id.uuidString] = date.timeIntervalSince1970
        }
        try? JSONFileStore.save(payload, to: fileName)
    }
}
