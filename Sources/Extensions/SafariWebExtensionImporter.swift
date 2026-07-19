import Foundation

/// A Safari Web Extension that Oriel can import into `WKWebExtension`.
struct SafariExtensionCandidate: Identifiable, Equatable, Sendable {
    var id: String { bundleIdentifier + "|" + appexURL.path }
    var displayName: String
    var version: String
    var bundleIdentifier: String
    var appexURL: URL
    var manifestURL: URL?
    var containingAppName: String?
    var kind: Kind

    enum Kind: String, Sendable {
        /// Modern Safari Web Extension (WebExtensions + appex wrapper).
        case safariWebExtension
        /// Legacy native Safari App Extension — not portable to WKWebView.
        case legacySafariAppExtension
        /// Safari content blocker appex — Oriel uses its own blocker engine.
        case contentBlocker
        /// Unknown / incomplete package.
        case unknown
    }

    var isImportable: Bool { kind == .safariWebExtension && manifestURL != nil }

    var statusDetail: String {
        switch kind {
        case .safariWebExtension:
            return manifestURL == nil
                ? "Safari Web Extension, but no manifest.json was found in the package."
                : "Safari Web Extension — can be imported into Oriel."
        case .legacySafariAppExtension:
            return "Legacy Safari App Extension (native). Apple does not allow these outside Safari."
        case .contentBlocker:
            return "Safari content blocker. Oriel already uses its own Shields filter engine."
        case .unknown:
            return "Not recognized as an importable Safari Web Extension."
        }
    }
}

/// Discovers and extracts Safari Web Extension packages for Oriel’s WKWebExtension host.
enum SafariWebExtensionImporter {
    static let webExtensionPoint = "com.apple.Safari.web-extension"
    static let legacyExtensionPoint = "com.apple.Safari.extension"
    static let contentBlockerPoint = "com.apple.Safari.content-blocker"

    // MARK: - Classification

    static func classify(appexURL: URL) -> SafariExtensionCandidate {
        let info = loadInfoPlist(at: appexURL) ?? [:]
        let extensionDict = info["NSExtension"] as? [String: Any] ?? [:]
        let point = (extensionDict["NSExtensionPointIdentifier"] as? String)
            ?? (extensionDict["NSExtensionPointName"] as? String)
            ?? ""
        let bundleID = (info["CFBundleIdentifier"] as? String)
            ?? appexURL.deletingPathExtension().lastPathComponent
        let name = (info["CFBundleDisplayName"] as? String)
            ?? (info["CFBundleName"] as? String)
            ?? appexURL.deletingPathExtension().lastPathComponent
        let version = (info["CFBundleShortVersionString"] as? String)
            ?? (info["CFBundleVersion"] as? String)
            ?? "—"
        let manifest = findManifest(in: appexURL)
        let kind: SafariExtensionCandidate.Kind
        switch point {
        case webExtensionPoint:
            kind = .safariWebExtension
        case legacyExtensionPoint:
            kind = .legacySafariAppExtension
        case contentBlockerPoint:
            kind = .contentBlocker
        default:
            kind = manifest != nil ? .safariWebExtension : .unknown
        }
        return SafariExtensionCandidate(
            displayName: name,
            version: version,
            bundleIdentifier: bundleID,
            appexURL: appexURL,
            manifestURL: manifest,
            containingAppName: containingAppName(for: appexURL),
            kind: kind
        )
    }

    // MARK: - Discovery (macOS Applications)

    /// Scans `/Applications` and `~/Applications` for Safari Web Extension `.appex` bundles.
    static func discoverInstalledCandidates(fileManager: FileManager = .default) -> [SafariExtensionCandidate] {
        var roots: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true)
        ]
        roots.append(
            fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications", isDirectory: true)
        )

        var found: [SafariExtensionCandidate] = []
        var seen = Set<String>()

        for root in roots {
            guard let apps = try? fileManager.contentsOfDirectory(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for appURL in apps where appURL.pathExtension.lowercased() == "app" {
                let plugins = appURL
                    .appendingPathComponent("Contents", isDirectory: true)
                    .appendingPathComponent("PlugIns", isDirectory: true)
                guard let plugins = try? fileManager.contentsOfDirectory(
                    at: plugins,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ) else { continue }

                for appex in plugins where appex.pathExtension.lowercased() == "appex" {
                    let candidate = classify(appexURL: appex)
                    guard candidate.kind == .safariWebExtension || candidate.kind == .legacySafariAppExtension else {
                        continue
                    }
                    if seen.contains(candidate.bundleIdentifier) { continue }
                    seen.insert(candidate.bundleIdentifier)
                    found.append(candidate)
                }
            }
        }

        return found.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    // MARK: - Staging / extraction

    /// Copies the WebExtension resource tree out of a Safari `.appex` (or project folder)
    /// into a clean directory Oriel can persist and load with `WKWebExtension(resourceBaseURL:)`.
    static func extractWebExtensionResources(
        from packageURL: URL,
        to destination: URL,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: packageURL.path, isDirectory: &isDirectory) else {
            throw SafariImportError.packageNotFound
        }

        let candidate = classify(appexURL: packageURL)
        if candidate.kind == .legacySafariAppExtension {
            throw SafariImportError.legacySafariOnly
        }
        if candidate.kind == .contentBlocker {
            throw SafariImportError.contentBlockerUnsupported
        }

        guard let manifest = candidate.manifestURL ?? findManifest(in: packageURL) else {
            if packageURL.pathExtension.lowercased() == "appex" {
                throw SafariImportError.missingManifestInAppex
            }
            throw SafariImportError.missingManifest
        }

        let resourceRoot = manifest.deletingLastPathComponent()
        // Copy only the WebExtension resource tree (not the native appex Mach-O / Info.plist).
        for item in try fileManager.contentsOfDirectory(at: resourceRoot, includingPropertiesForKeys: nil) {
            let name = item.lastPathComponent
            // Skip native appex scaffolding if somehow present next to the manifest.
            if ["_CodeSignature", "SC_Info", "MacOS", "Frameworks"].contains(name) { continue }
            if name == "Info.plist", resourceRoot.lastPathComponent == "Contents" { continue }
            let target = destination.appendingPathComponent(name)
            if fileManager.fileExists(atPath: target.path) {
                try fileManager.removeItem(at: target)
            }
            try fileManager.copyItem(at: item, to: target)
        }

        let copiedManifest = destination.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: copiedManifest.path) else {
            throw SafariImportError.missingManifest
        }

        try normalizeSafariManifestIfNeeded(at: copiedManifest)
    }

    /// Soft-normalize Safari-only manifest keys so WebKit accepts more packages.
    static func normalizeSafariManifestIfNeeded(at manifestURL: URL) throws {
        guard let data = try? Data(contentsOf: manifestURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        var changed = false

        // Some Safari packages put icons only under browser_action / action nested dicts — leave those.
        // Ensure MV3 background service_worker packages aren't marked persistent (iOS rejects that).
        if var background = root["background"] as? [String: Any] {
            if background["service_worker"] != nil, background["persistent"] as? Bool == true {
                background["persistent"] = false
                root["background"] = background
                changed = true
            }
        }

        // Drop Safari-only browser_specific_settings; keep gecko/other if present.
        if var bss = root["browser_specific_settings"] as? [String: Any], bss["safari"] != nil {
            bss.removeValue(forKey: "safari")
            if bss.isEmpty {
                root.removeValue(forKey: "browser_specific_settings")
            } else {
                root["browser_specific_settings"] = bss
            }
            changed = true
        }

        // Prefer `browser_specific_settings` / `applications` leftovers don't block WebKit, but
        // strip empty Safari-only permission stubs that confuse validation.
        if let permissions = root["permissions"] as? [String] {
            let filtered = permissions.filter { $0 != "nativeMessaging" || root["browser_specific_settings"] == nil }
            if filtered.count != permissions.count {
                root["permissions"] = filtered
                changed = true
            }
        }

        guard changed else { return }
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: manifestURL, options: .atomic)
    }

    // MARK: - Helpers

    static func findManifest(in root: URL, fileManager: FileManager = .default) -> URL? {
        let preferred = [
            root.appendingPathComponent("manifest.json"),
            root.appendingPathComponent("Contents/Resources/manifest.json"),
            root.appendingPathComponent("Resources/manifest.json")
        ]
        for url in preferred where fileManager.fileExists(atPath: url.path) {
            return url
        }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "manifest.json" {
            // Prefer Resources/manifest.json over accidental copies in build products.
            return fileURL
        }
        return nil
    }

    static func loadInfoPlist(at appexURL: URL) -> [String: Any]? {
        let candidates = [
            appexURL.appendingPathComponent("Contents/Info.plist"),
            appexURL.appendingPathComponent("Info.plist")
        ]
        for url in candidates {
            if let dict = NSDictionary(contentsOf: url) as? [String: Any] {
                return dict
            }
        }
        if let bundle = Bundle(url: appexURL), let info = bundle.infoDictionary {
            return info
        }
        return nil
    }

    private static func containingAppName(for appexURL: URL) -> String? {
        // …/Something.app/Contents/PlugIns/Foo.appex
        var url = appexURL
        for _ in 0..<4 {
            url = url.deletingLastPathComponent()
            if url.pathExtension.lowercased() == "app" {
                return url.deletingPathExtension().lastPathComponent
            }
        }
        return nil
    }
}

enum SafariImportError: LocalizedError, Equatable {
    case packageNotFound
    case legacySafariOnly
    case contentBlockerUnsupported
    case missingManifest
    case missingManifestInAppex

    var errorDescription: String? {
        switch self {
        case .packageNotFound:
            return "That Safari extension package could not be found."
        case .legacySafariOnly:
            return "This is a legacy Safari App Extension (native). Only Safari Web Extensions (with manifest.json) can run in Oriel."
        case .contentBlockerUnsupported:
            return "Safari content blockers stay in Safari. Use Oriel Shields for blocking in Oriel."
        case .missingManifest:
            return "No WebExtension manifest.json found in this package."
        case .missingManifestInAppex:
            return "This .appex has no WebExtension resources. App Store Safari packages that are native-only cannot be imported — look for a Safari Web Extension (com.apple.Safari.web-extension) that still contains manifest.json."
        }
    }
}
