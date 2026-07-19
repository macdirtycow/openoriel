import Foundation
import Observation

/// Lightweight cross-device sync via iCloud Key-Value Store (bookmarks, queue, settings, tabs, history).
@Observable
@MainActor
final class iCloudSyncService {
    private let defaults = NSUbiquitousKeyValueStore.default
    private let bookmarksKey = "oriel.sync.bookmarks.v1"
    private let settingsKey = "oriel.sync.settings.v2"
    private let queueKey = "oriel.sync.linkqueue.v1"
    private let sessionKey = "oriel.sync.session.v1"
    private let historyKey = "oriel.sync.history.v1"
    private let enabledKey = "oriel.icloudSyncEnabled"
    private let localSettingsStampKey = "oriel.sync.settings.localStamp"
    private let localSessionStampKey = "oriel.sync.session.localStamp"

    /// Caps history payload so KVS stays under its ~1 MB budget.
    private let historySyncLimit = 200

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                pushAll()
            }
        }
    }

    /// Tabs last seen from another device (for “Open from other devices”).
    private(set) var remoteSession: SessionSnapshot?

    private weak var bookmarks: BookmarkStore?
    private weak var settings: BrowserSettings?
    private weak var linkQueue: LinkQueueStore?
    private weak var history: HistoryStore?
    private var sessionProvider: (() -> SessionSnapshot)?
    private var onRemoteSessionNewer: ((SessionSnapshot) -> Void)?

    init() {
        if UserDefaults.standard.object(forKey: enabledKey) == nil {
            isEnabled = false
        } else {
            isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        }
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: defaults,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                self?.handleExternalChange(note)
            }
        }
        defaults.synchronize()
    }

    func attach(
        bookmarks: BookmarkStore,
        settings: BrowserSettings,
        linkQueue: LinkQueueStore,
        history: HistoryStore,
        sessionProvider: @escaping () -> SessionSnapshot,
        onRemoteSessionNewer: @escaping (SessionSnapshot) -> Void
    ) {
        self.bookmarks = bookmarks
        self.settings = settings
        self.linkQueue = linkQueue
        self.history = history
        self.sessionProvider = sessionProvider
        self.onRemoteSessionNewer = onRemoteSessionNewer
        if isEnabled {
            pushAll()
            pullAll()
            pushAll()
        }
    }

    /// Call after local appearance / engine / queue / bookmark / history / tab edits.
    func noteLocalChange() {
        guard isEnabled else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: localSettingsStampKey)
        pushAll()
    }

    func noteSessionChange() {
        guard isEnabled else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: localSessionStampKey)
        pushSession()
        defaults.synchronize()
    }

    func pushAll() {
        guard isEnabled else { return }
        if let bookmarks {
            if let data = try? JSONEncoder().encode(bookmarks.bookmarks) {
                defaults.set(data, forKey: bookmarksKey)
            }
        }
        if let settings {
            let stamp = UserDefaults.standard.double(forKey: localSettingsStampKey)
            let payload: [String: String] = [
                "searchEngine": settings.searchEngine.rawValue,
                "appearance": settings.appearance.rawValue,
                "accentTheme": settings.accentTheme.rawValue,
                "backgroundTheme": settings.backgroundTheme.rawValue,
                "edition": settings.edition.rawValue,
                "updatedAt": String(stamp > 0 ? stamp : Date().timeIntervalSince1970)
            ]
            if let data = try? JSONEncoder().encode(payload) {
                defaults.set(data, forKey: settingsKey)
            }
        }
        if let linkQueue {
            if let data = try? JSONEncoder().encode(linkQueue.items) {
                defaults.set(data, forKey: queueKey)
            }
        }
        if let history {
            let slice = Array(history.entries.prefix(historySyncLimit))
            if let data = try? JSONEncoder().encode(slice) {
                defaults.set(data, forKey: historyKey)
            }
        }
        pushSession()
        defaults.synchronize()
    }

    func pullAll() {
        guard isEnabled else { return }
        if let data = defaults.data(forKey: bookmarksKey),
           let remote = try? JSONDecoder().decode([Bookmark].self, from: data),
           let bookmarks {
            bookmarks.mergeRemote(remote)
        }
        if let data = defaults.data(forKey: settingsKey),
           let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let settings {
            let remoteStamp = Double(payload["updatedAt"] ?? "") ?? 0
            let localStamp = UserDefaults.standard.double(forKey: localSettingsStampKey)
            if remoteStamp > localStamp {
                if let raw = payload["searchEngine"], let engine = SearchEngine(rawValue: raw) {
                    settings.searchEngine = engine
                }
                if let raw = payload["appearance"], let mode = AppAppearance(rawValue: raw) {
                    settings.appearance = mode
                }
                if let raw = payload["accentTheme"], let theme = BrowserAccentTheme(rawValue: raw) {
                    settings.accentTheme = theme
                }
                if let raw = payload["backgroundTheme"], let theme = BrowserBackgroundTheme(rawValue: raw) {
                    settings.backgroundTheme = theme
                }
                if let raw = payload["edition"], let edition = BrowserEdition(rawValue: raw) {
                    settings.edition = edition
                }
                UserDefaults.standard.set(remoteStamp, forKey: localSettingsStampKey)
            }
        }
        if let data = defaults.data(forKey: queueKey),
           let remote = try? JSONDecoder().decode([QueuedLink].self, from: data),
           let linkQueue {
            linkQueue.mergeUnion(remote)
        }
        if let data = defaults.data(forKey: historyKey),
           let remote = try? JSONDecoder().decode([HistoryEntry].self, from: data),
           let history {
            history.mergeRemote(remote)
        }
        pullSession()
    }

    private func pushSession() {
        guard let sessionProvider else { return }
        var snapshot = sessionProvider()
        let stamp = UserDefaults.standard.double(forKey: localSessionStampKey)
        if stamp > 0 {
            snapshot.savedAt = Date(timeIntervalSince1970: stamp)
        }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: sessionKey)
        }
    }

    private func pullSession() {
        guard let data = defaults.data(forKey: sessionKey),
              let remote = try? JSONDecoder().decode(SessionSnapshot.self, from: data) else {
            return
        }
        remoteSession = remote
        let localStamp = UserDefaults.standard.double(forKey: localSessionStampKey)
        let remoteStamp = remote.savedAt.timeIntervalSince1970
        // Only auto-apply when remote is clearly newer than this device's last edit.
        if remoteStamp > localStamp + 1 {
            UserDefaults.standard.set(remoteStamp, forKey: localSessionStampKey)
            onRemoteSessionNewer?(remote)
        }
    }

    private func handleExternalChange(_ note: Notification) {
        guard isEnabled else { return }
        pullAll()
    }
}
