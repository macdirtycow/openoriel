import Foundation

/// Built-in compatibility layer that soft-rewrites Chrome / Firefox / Safari
/// WebExtension manifests so Apple’s `WKWebExtension` (macOS 15.4+ / iOS 18.4+)
/// accepts more packages — especially on iPhone and iPad.
///
/// This is not a full Chromium/Gecko shim. It only adjusts packaging / manifest
/// shape. APIs that WebKit does not implement still will not run.
enum ManifestCompatNormalizer {
    /// Permissions that commonly break WebKit load or are meaningless outside Chrome/Firefox.
    /// Kept in sync with ``ExtensionCompatibility/blockedPermissions`` where overlapping.
    static let stripPermissions: Set<String> = [
        "debugger",
        "proxy",
        "privacy",
        "fontSettings",
        "enterprise.deviceAttributes",
        "enterprise.hardwarePlatform",
        "enterprise.platformKeys",
        "loginState",
        "gcm",
        "system.cpu",
        "system.memory",
        "system.storage",
        "system.display"
    ]

    /// Soft-normalize `manifest.json` in place. Safe to call repeatedly.
    @discardableResult
    static func normalize(at manifestURL: URL) throws -> Bool {
        guard let data = try? Data(contentsOf: manifestURL),
              var root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        var changed = false

        // --- Action aliases (Chrome MV2 / Firefox) ---
        if root["action"] == nil {
            if let browserAction = root["browser_action"] {
                root["action"] = browserAction
                root.removeValue(forKey: "browser_action")
                changed = true
            } else if let pageAction = root["page_action"] {
                root["action"] = pageAction
                root.removeValue(forKey: "page_action")
                changed = true
            }
        } else {
            if root["browser_action"] != nil {
                root.removeValue(forKey: "browser_action")
                changed = true
            }
            if root["page_action"] != nil {
                root.removeValue(forKey: "page_action")
                changed = true
            }
        }

        // --- Background: WebKit rejects ANY `persistent` key ("Invalid `persistent` manifest entry") ---
        if var background = root["background"] as? [String: Any] {
            var bgChanged = false
            if background["persistent"] != nil {
                // Do not rewrite to false — WKWebExtension rejects the key entirely.
                background.removeValue(forKey: "persistent")
                bgChanged = true
            }
            // Prefer a single service_worker when both shapes are present.
            if background["service_worker"] != nil, background["scripts"] != nil {
                background.removeValue(forKey: "scripts")
                bgChanged = true
            }
            // MV3-shaped packages sometimes still list `scripts` without a worker.
            if background["service_worker"] == nil,
               let scripts = background["scripts"] as? [String],
               let first = scripts.first,
               (root["manifest_version"] as? Int) == 3 {
                background["service_worker"] = first
                background.removeValue(forKey: "scripts")
                bgChanged = true
            }
            if bgChanged {
                root["background"] = background
                changed = true
            }
        }

        // --- Drop Safari-only / legacy Firefox packaging keys ---
        if var bss = root["browser_specific_settings"] as? [String: Any], bss["safari"] != nil {
            bss.removeValue(forKey: "safari")
            if bss.isEmpty {
                root.removeValue(forKey: "browser_specific_settings")
            } else {
                root["browser_specific_settings"] = bss
            }
            changed = true
        }
        if root["applications"] != nil {
            // Legacy Firefox `applications.gecko` — WebKit ignores it; drop to avoid validators.
            root.removeValue(forKey: "applications")
            changed = true
        }

        // --- Permissions cleanup ---
        if let permissions = root["permissions"] as? [String] {
            let filtered = permissions.filter { !stripPermissions.contains($0) }
            // nativeMessaging needs a native host Oriel does not provide.
            let withoutNative = filtered.filter { $0 != "nativeMessaging" }
            if withoutNative.count != permissions.count {
                root["permissions"] = withoutNative
                changed = true
            }
        }
        if let optional = root["optional_permissions"] as? [String] {
            let filtered = optional.filter { !stripPermissions.contains($0) && $0 != "nativeMessaging" }
            if filtered.count != optional.count {
                root["optional_permissions"] = filtered
                changed = true
            }
        }

        // --- options_ui chrome_style is Chrome-only noise ---
        if var optionsUI = root["options_ui"] as? [String: Any], optionsUI["chrome_style"] != nil {
            optionsUI.removeValue(forKey: "chrome_style")
            root["options_ui"] = optionsUI
            changed = true
        }

        // Ensure a name exists (some theme packs omit it).
        if root["name"] == nil {
            root["name"] = manifestURL.deletingLastPathComponent().lastPathComponent
            changed = true
        }

        guard changed else { return false }
        let out = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        try out.write(to: manifestURL, options: .atomic)
        return true
    }

    /// Normalize every `manifest.json` under a staged package root.
    static func normalizePackage(at packageRoot: URL, fileManager: FileManager = .default) {
        let manifests = [
            packageRoot.appendingPathComponent("manifest.json"),
            packageRoot.appendingPathComponent("Contents/Resources/manifest.json"),
            packageRoot.appendingPathComponent("Resources/manifest.json")
        ]
        for url in manifests where fileManager.fileExists(atPath: url.path) {
            try? normalize(at: url)
            return
        }
        if let found = SafariWebExtensionImporter.findManifest(in: packageRoot, fileManager: fileManager) {
            try? normalize(at: found)
        }
    }
}
