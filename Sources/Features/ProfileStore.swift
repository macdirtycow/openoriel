import Foundation
import WebKit

/// Browser profile / container with isolated website data (cookies, storage, cache).
struct BrowserProfile: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var isPrivateContainer: Bool
    /// When true, uses `WKWebsiteDataStore.default()` so pre-profile installs keep cookies.
    var usesSharedDefaultStore: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        isPrivateContainer: Bool = false,
        usesSharedDefaultStore: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isPrivateContainer = isPrivateContainer
        self.usesSharedDefaultStore = usesSharedDefaultStore
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, isPrivateContainer, usesSharedDefaultStore, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        isPrivateContainer = try c.decodeIfPresent(Bool.self, forKey: .isPrivateContainer) ?? false
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        // Older snapshots: treat the original Personal profile as the shared default store.
        usesSharedDefaultStore = try c.decodeIfPresent(Bool.self, forKey: .usesSharedDefaultStore)
            ?? (name == "Personal")
    }
}

@Observable
@MainActor
final class ProfileStore {
    private(set) var profiles: [BrowserProfile] = []
    private(set) var activeProfileID: UUID
    private let fileName = "profiles.json"

    private struct Snapshot: Codable {
        var profiles: [BrowserProfile]
        var activeProfileID: UUID
    }

    init() {
        if let loaded = try? JSONFileStore.load(Snapshot.self, from: fileName), !loaded.profiles.isEmpty {
            profiles = loaded.profiles
            activeProfileID = loaded.activeProfileID
        } else {
            // Fresh installs: Personal is already an isolated cookie container.
            let personal = BrowserProfile(name: "Personal", usesSharedDefaultStore: false)
            _ = WKWebsiteDataStore(forIdentifier: personal.id)
            profiles = [personal]
            activeProfileID = personal.id
            persist()
        }
    }

    var activeProfile: BrowserProfile {
        profiles.first(where: { $0.id == activeProfileID }) ?? profiles[0]
    }

    /// Website data store for the active profile (or a private/ephemeral jar).
    func dataStore(isPrivateTab: Bool) -> WKWebsiteDataStore {
        dataStore(for: activeProfile, isPrivateTab: isPrivateTab)
    }

    func dataStore(for profile: BrowserProfile, isPrivateTab: Bool) -> WKWebsiteDataStore {
        if isPrivateTab || profile.isPrivateContainer {
            return .nonPersistent()
        }
        // Legacy Personal profiles keep the shared default jar so existing logins survive.
        // Every other profile (and new Personal installs) uses an isolated named store.
        if profile.usesSharedDefaultStore {
            return .default()
        }
        return WKWebsiteDataStore(forIdentifier: profile.id)
    }

    /// Move a legacy shared-default profile onto its own cookie jar (clears that profile’s prior default cookies from use).
    func convertToIsolatedStore(id: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        guard profiles[index].usesSharedDefaultStore else { return }
        profiles[index].usesSharedDefaultStore = false
        _ = WKWebsiteDataStore(forIdentifier: profiles[index].id)
        persist()
    }

    @discardableResult
    func create(name: String, isPrivateContainer: Bool = false) -> BrowserProfile {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let profile = BrowserProfile(
            name: trimmed.isEmpty ? "Profile \(profiles.count + 1)" : trimmed,
            isPrivateContainer: isPrivateContainer,
            usesSharedDefaultStore: false
        )
        // Touch the store so WebKit creates it immediately.
        if !isPrivateContainer {
            _ = WKWebsiteDataStore(forIdentifier: profile.id)
        }
        profiles.append(profile)
        persist()
        return profile
    }

    func rename(id: UUID, name: String) {
        guard let index = profiles.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        profiles[index].name = trimmed
        persist()
    }

    func delete(id: UUID) {
        guard profiles.count > 1 else { return }
        guard let profile = profiles.first(where: { $0.id == id }) else { return }
        profiles.removeAll { $0.id == id }
        if activeProfileID == id {
            activeProfileID = profiles[0].id
        }
        persist()
        if !profile.usesSharedDefaultStore, !profile.isPrivateContainer {
            Task {
                await Self.removeDataStore(for: profile.id)
            }
        }
    }

    func select(id: UUID) {
        guard profiles.contains(where: { $0.id == id }) else { return }
        activeProfileID = id
        persist()
    }

    private static func removeDataStore(for id: UUID) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            WKWebsiteDataStore.remove(forIdentifier: id) { _ in
                continuation.resume()
            }
        }
    }

    private func persist() {
        try? JSONFileStore.save(Snapshot(profiles: profiles, activeProfileID: activeProfileID), to: fileName)
    }
}
