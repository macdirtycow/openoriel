import Foundation
import Observation

enum SitePermission: String, CaseIterable, Identifiable, Codable, Sendable {
    case camera
    case microphone
    case location

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .camera: "Camera"
        case .microphone: "Microphone"
        case .location: "Location"
        }
    }

    var systemImage: String {
        switch self {
        case .camera: "camera"
        case .microphone: "mic"
        case .location: "location"
        }
    }
}

enum PermissionDecision: String, Codable, Sendable {
    case ask
    case allow
    case deny
}

@Observable
@MainActor
final class WebsitePermissionManager {
    /// host -> permission -> decision
    private(set) var decisions: [String: [SitePermission: PermissionDecision]] = [:]
    private let fileName = "site-permissions.json"

    init() {
        if let loaded = try? JSONFileStore.load([String: [String: String]].self, from: fileName) {
            var parsed: [String: [SitePermission: PermissionDecision]] = [:]
            for (host, map) in loaded {
                var inner: [SitePermission: PermissionDecision] = [:]
                for (key, value) in map {
                    if let permission = SitePermission(rawValue: key),
                       let decision = PermissionDecision(rawValue: value) {
                        inner[permission] = decision
                    }
                }
                parsed[host] = inner
            }
            decisions = parsed
        }
    }

    func decision(for host: String?, permission: SitePermission) -> PermissionDecision {
        guard let host = host?.lowercased(), !host.isEmpty else { return .ask }
        return decisions[host]?[permission] ?? .ask
    }

    func setDecision(_ decision: PermissionDecision, for host: String?, permission: SitePermission) {
        guard let host = host?.lowercased(), !host.isEmpty else { return }
        var map = decisions[host] ?? [:]
        map[permission] = decision
        decisions[host] = map
        persist()
    }

    func grantedPermissions(for host: String?) -> [SitePermission] {
        SitePermission.allCases.filter { decision(for: host, permission: $0) == .allow }
    }

    func clearAll() {
        decisions = [:]
        persist()
    }

    private func persist() {
        var raw: [String: [String: String]] = [:]
        for (host, map) in decisions {
            raw[host] = Dictionary(uniqueKeysWithValues: map.map { ($0.key.rawValue, $0.value.rawValue) })
        }
        try? JSONFileStore.save(raw, to: fileName)
    }
}
