import Foundation
import CryptoKit
import LocalAuthentication
import Observation
import Security

struct VaultCredential: Identifiable, Codable, Equatable, Sendable, Hashable {
    var id: UUID
    var host: String
    var username: String
    var password: String
    var notes: String
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        host: String,
        username: String,
        password: String,
        notes: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.host = host
        self.username = username
        self.password = password
        self.notes = notes
        self.updatedAt = updatedAt
    }

    var displayHost: String {
        host.isEmpty ? "Unknown site" : host
    }
}

/// Oriel-owned encrypted password vault (Mac-first; works on iOS too).
/// Secrets are AES-GCM encrypted at rest; the vault key lives in the system Keychain.
@Observable
@MainActor
final class PasswordVaultStore {
    private(set) var credentials: [VaultCredential] = []
    private(set) var isUnlocked = false
    private(set) var lastError: String?
    private(set) var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: enabledKey) }
    }

    private let fileName = "password-vault.sealed"
    private let enabledKey = "oriel.passwordVaultEnabled"
    private let keychainService = "net.inveil.oriel.password-vault"
    private let keychainAccount = "vault-key-v1"
    private var unlockTask: Task<Void, Never>?

    init() {
        isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    var isEmpty: Bool { credentials.isEmpty }

    func credentials(matchingHost host: String?) -> [VaultCredential] {
        guard let host = host?.lowercased(), !host.isEmpty else { return [] }
        return credentials.filter { entry in
            let h = entry.host.lowercased()
            return h == host || host.hasSuffix("." + h) || h.hasSuffix("." + host)
        }
        .sorted { $0.updatedAt > $1.updatedAt }
    }

    @discardableResult
    func unlock(reason: String = "Unlock Oriel Password Vault") async -> Bool {
        lastError = nil
        do {
            _ = try await loadVaultKey(reason: reason)
            try loadSealedVault()
            isUnlocked = true
            scheduleAutoLock()
            return true
        } catch {
            lastError = error.localizedDescription
            isUnlocked = false
            credentials = []
            return false
        }
    }

    func lock() {
        unlockTask?.cancel()
        credentials = []
        isUnlocked = false
    }

    func upsert(_ credential: VaultCredential) throws {
        try ensureUnlocked()
        var next = credential
        next.host = normalizedHost(next.host)
        next.updatedAt = .now
        if let idx = credentials.firstIndex(where: { $0.id == next.id }) {
            credentials[idx] = next
        } else if let idx = credentials.firstIndex(where: {
            $0.host == next.host && $0.username == next.username
        }) {
            next.id = credentials[idx].id
            credentials[idx] = next
        } else {
            credentials.insert(next, at: 0)
        }
        try persistSealedVault()
        scheduleAutoLock()
    }

    func delete(id: UUID) throws {
        try ensureUnlocked()
        credentials.removeAll { $0.id == id }
        try persistSealedVault()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        if !enabled {
            lock()
        }
    }

    // MARK: - Crypto / persistence

    private func ensureUnlocked() throws {
        guard isUnlocked else {
            throw VaultError.locked
        }
    }

    private func scheduleAutoLock() {
        unlockTask?.cancel()
        unlockTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 15 * 60 * 1_000_000_000)
            guard !Task.isCancelled else { return }
            lock()
        }
    }

    private func normalizedHost(_ raw: String) -> String {
        var host = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let url = URL(string: host), let urlHost = url.host {
            host = urlHost.lowercased()
        }
        if host.hasPrefix("www.") {
            host = String(host.dropFirst(4))
        }
        return host
    }

    private func loadVaultKey(reason: String) async throws -> SymmetricKey {
        let context = LAContext()
        var authError: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) {
            let ok = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
                context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, error in
                    if let error {
                        cont.resume(throwing: error)
                    } else {
                        cont.resume(returning: success)
                    }
                }
            }
            guard ok else { throw VaultError.authFailed }
        }
        if let existing = try readKeyFromKeychain() {
            return existing
        }
        let key = SymmetricKey(size: .bits256)
        try storeKeyInKeychain(key)
        return key
    }

    private func loadSealedVault() throws {
        guard let dir = try? JSONFileStore.applicationSupportDirectory() else {
            credentials = []
            return
        }
        let url = dir.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: url.path) else {
            credentials = []
            return
        }
        let blob = try Data(contentsOf: url)
        let key = try readKeyFromKeychain() ?? { throw VaultError.missingKey }()
        let box = try AES.GCM.SealedBox(combined: blob)
        let plain = try AES.GCM.open(box, using: key)
        credentials = try JSONDecoder().decode([VaultCredential].self, from: plain)
    }

    private func persistSealedVault() throws {
        let key = try readKeyFromKeychain() ?? { throw VaultError.missingKey }()
        let plain = try JSONEncoder().encode(credentials)
        let sealed = try AES.GCM.seal(plain, using: key)
        guard let combined = sealed.combined else { throw VaultError.sealFailed }
        let dir = try JSONFileStore.applicationSupportDirectory()
        let url = dir.appendingPathComponent(fileName)
        try combined.write(to: url, options: [.atomic])
    }

    private func readKeyFromKeychain() throws -> SymmetricKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw VaultError.keychain(status)
        }
        return SymmetricKey(data: data)
    }

    private func storeKeyInKeychain(_ key: SymmetricKey) throws {
        let data = key.withUnsafeBytes { Data($0) }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]
        SecItemDelete(query as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
    }
}

enum VaultError: LocalizedError {
    case locked
    case authFailed
    case missingKey
    case sealFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .locked: return "Password Vault is locked."
        case .authFailed: return "Authentication failed."
        case .missingKey: return "Vault key missing from Keychain."
        case .sealFailed: return "Could not encrypt vault."
        case .keychain(let status): return "Keychain error (\(status))."
        }
    }
}
