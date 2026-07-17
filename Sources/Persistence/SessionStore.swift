import Foundation

struct SessionSnapshot: Codable, Equatable, Sendable {
    struct TabSnapshot: Codable, Equatable, Sendable {
        var id: UUID
        var urlString: String
        var title: String
        var isPrivate: Bool
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
