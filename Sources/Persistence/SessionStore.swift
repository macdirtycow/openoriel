import Foundation

struct SessionSnapshot: Codable, Equatable, Sendable {
    struct TabSnapshot: Codable, Equatable, Sendable {
        var id: UUID
        var urlString: String
        var title: String
        var isPrivate: Bool
        var isPinned: Bool

        init(id: UUID, urlString: String, title: String, isPrivate: Bool, isPinned: Bool = false) {
            self.id = id
            self.urlString = urlString
            self.title = title
            self.isPrivate = isPrivate
            self.isPinned = isPinned
        }

        enum CodingKeys: String, CodingKey {
            case id, urlString, title, isPrivate, isPinned
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            urlString = try c.decode(String.self, forKey: .urlString)
            title = try c.decode(String.self, forKey: .title)
            isPrivate = try c.decode(Bool.self, forKey: .isPrivate)
            isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        }
    }

    var tabs: [TabSnapshot]
    var activeTabID: UUID?
    var savedAt: Date
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

    func save(_ snapshot: SessionSnapshot) {
        try? JSONFileStore.save(snapshot, to: fileName)
    }

    func clear() {
        let url = try? JSONFileStore.applicationSupportDirectory().appendingPathComponent(fileName)
        if let url {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
