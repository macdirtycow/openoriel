import Foundation
import Observation

/// Local settings mirror used for CloudKit/iCloud KVS sync of lightweight preferences + bookmarks.
@Observable
@MainActor
final class iCloudSyncService {
    private let defaults = NSUbiquitousKeyValueStore.default
    private let bookmarksKey = "oriel.sync.bookmarks.v1"
    private let settingsKey = "oriel.sync.settings.v2"
    private let queueKey = "oriel.sync.linkqueue.v1"
    private let enabledKey = "oriel.icloudSyncEnabled"
    private let localSettingsStampKey = "oriel.sync.settings.localStamp"

    var isEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isEnabled, forKey: enabledKey)
            if isEnabled {
                pushAll()
            }
        }
    }

    private weak var bookmarks: BookmarkStore?
    private weak var settings: BrowserSettings?
    private weak var linkQueue: LinkQueueStore?

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

    func attach(bookmarks: BookmarkStore, settings: BrowserSettings, linkQueue: LinkQueueStore) {
        self.bookmarks = bookmarks
        self.settings = settings
        self.linkQueue = linkQueue
        if isEnabled {
            // Push local first so an empty/older remote does not wipe this device on launch.
            pushAll()
            pullAll()
            pushAll()
        }
    }

    /// Call after local appearance / engine / queue / bookmark edits so remotes stay current.
    func noteLocalChange() {
        guard isEnabled else { return }
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: localSettingsStampKey)
        pushAll()
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
        defaults.synchronize()
    }

    func pullAll() {
        guard isEnabled else { return }
        if let data = defaults.data(forKey: bookmarksKey),
           let remote = try? JSONDecoder().decode([Bookmark].self, from: data),
           let bookmarks {
            var map = Dictionary(uniqueKeysWithValues: bookmarks.bookmarks.map { ($0.id, $0) })
            for item in remote {
                map[item.id] = item
            }
            bookmarks.replaceAll(Array(map.values))
        }
        if let data = defaults.data(forKey: settingsKey),
           let payload = try? JSONDecoder().decode([String: String].self, from: data),
           let settings {
            let remoteStamp = Double(payload["updatedAt"] ?? "") ?? 0
            let localStamp = UserDefaults.standard.double(forKey: localSettingsStampKey)
            // Only apply remote settings when they are strictly newer than local edits.
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
                UserDefaults.standard.set(remoteStamp, forKey: localSettingsStampKey)
            }
        }
        if let data = defaults.data(forKey: queueKey),
           let remote = try? JSONDecoder().decode([QueuedLink].self, from: data),
           let linkQueue {
            linkQueue.mergeUnion(remote)
        }
    }

    private func handleExternalChange(_ note: Notification) {
        guard isEnabled else { return }
        pullAll()
    }
}
