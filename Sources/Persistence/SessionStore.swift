import Foundation

struct SessionSnapshot: Codable, Equatable, Sendable {
    struct TabSnapshot: Codable, Equatable, Sendable {
        var id: UUID
        var urlString: String
        var title: String
        var isPrivate: Bool
        var isPinned: Bool
        var groupID: UUID?

        init(id: UUID, urlString: String, title: String, isPrivate: Bool, isPinned: Bool = false, groupID: UUID? = nil) {
            self.id = id
            self.urlString = urlString
            self.title = title
            self.isPrivate = isPrivate
            self.isPinned = isPinned
            self.groupID = groupID
        }

        enum CodingKeys: String, CodingKey {
            case id, urlString, title, isPrivate, isPinned, groupID
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            urlString = try c.decode(String.self, forKey: .urlString)
            title = try c.decode(String.self, forKey: .title)
            isPrivate = try c.decode(Bool.self, forKey: .isPrivate)
            isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
            groupID = try c.decodeIfPresent(UUID.self, forKey: .groupID)
        }
    }

    var tabs: [TabSnapshot]
    var activeTabID: UUID?
    var groups: [TabGroup]
    var savedAt: Date

    enum CodingKeys: String, CodingKey {
        case tabs, activeTabID, groups, savedAt
    }

    init(tabs: [TabSnapshot], activeTabID: UUID?, groups: [TabGroup] = [], savedAt: Date) {
        self.tabs = tabs
        self.activeTabID = activeTabID
        self.groups = groups
        self.savedAt = savedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        tabs = try c.decode([TabSnapshot].self, forKey: .tabs)
        activeTabID = try c.decodeIfPresent(UUID.self, forKey: .activeTabID)
        groups = try c.decodeIfPresent([TabGroup].self, forKey: .groups) ?? []
        savedAt = try c.decode(Date.self, forKey: .savedAt)
    }
}

@MainActor
final class SessionStore {
    private let fileName = "session.json"
    private let defaults: UserDefaults
    private let restoreKey = "oriel.restoreSession"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var restorePreviousSession: Bool {
        get {
            if defaults.object(forKey: restoreKey) == nil { return true }
            return defaults.bool(forKey: restoreKey)
        }
        set { defaults.set(newValue, forKey: restoreKey) }
    }

    func load() -> SessionSnapshot? {
        guard restorePreviousSession else { return nil }
        return try? JSONFileStore.load(SessionSnapshot.self, from: fileName)
    }

    /// Persists the open-tab snapshot only when session restore is enabled,
    /// so turning restore off does not wipe the last good session on disk.
    func save(_ snapshot: SessionSnapshot) {
        guard restorePreviousSession else { return }
        try? JSONFileStore.save(snapshot, to: fileName)
    }

    func clear() {
        let url = try? JSONFileStore.applicationSupportDirectory().appendingPathComponent(fileName)
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
