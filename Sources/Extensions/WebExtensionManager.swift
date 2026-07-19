import Foundation
import Observation
import WebKit
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct InstalledExtensionInfo: Identifiable, Equatable, Sendable {
    let id: String
    var displayName: String
    var version: String
    var isEnabled: Bool
    var directoryName: String
    /// Chrome Web Store id when installed from the store (stable across reinstalls).
    var chromeStoreID: String?
    /// Firefox AMO slug when installed from addons.mozilla.org.
    var firefoxSlug: String?
}

/// Loads Chrome/Firefox-style WebExtensions via Apple’s `WKWebExtension` (macOS 15.4+ / iOS 18.4+).
@Observable
@MainActor
final class WebExtensionManager {
    private(set) var extensions: [InstalledExtensionInfo] = []
    private(set) var lastError: String?
    private(set) var isSupported: Bool = false
    private(set) var statusMessage: String?
    private(set) var isInstallingFromStore = false
    /// Safari Web Extension `.appex` candidates discovered under Applications (macOS).
    private(set) var safariCandidates: [SafariExtensionCandidate] = []
    private(set) var isScanningSafari = false

    /// Applies Chrome/Firefox/Safari static themes from packages that include `theme`.
    weak var themeStore: ExtensionThemeStore?

    /// Permissions the user allowed in the install review sheet (cleared after next load).
    private var pendingAllowedPermissions: Set<String>?
    /// Directory / store id hint for the install currently under review.
    private var pendingInstallDirectoryHint: String?
    /// Persisted per-directory denied permissions from install review.
    private var deniedPermissionsByDirectory: [String: Set<String>] = [:]
    private let deniedPermissionsFileName = "extension-denied-permissions.json"

    private var controllerStorage: AnyObject?
    private var hostStorage: AnyObject?
    private let fileManager = FileManager.default
    private let catalogName = "extensions-catalog.json"

    init() {
        deniedPermissionsByDirectory = Self.loadDeniedPermissions(fileName: deniedPermissionsFileName)
        #if os(macOS)
        if #available(macOS 15.4, *) {
            bootstrapController()
        } else {
            isSupported = false
            lastError = "Web extensions require macOS 15.4 or later."
        }
        #elseif os(iOS)
        if #available(iOS 18.4, *) {
            bootstrapController()
        } else {
            isSupported = false
            lastError = "Web extensions require iOS 18.4 or later."
        }
        #else
        isSupported = false
        lastError = "Web extensions are not available on this platform."
        #endif
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func bootstrapController() {
        isSupported = true
        let controller = WKWebExtensionController()
        let host = WebExtensionHost()
        controller.delegate = host
        controllerStorage = controller
        hostStorage = host
        Task { await reloadFromDisk() }
    }

    /// Attached to normal-tab `WKWebViewConfiguration` when supported.
    var webExtensionControllerForConfiguration: AnyObject? {
        #if os(macOS)
        if #available(macOS 15.4, *), isSupported {
            return controllerStorage
        }
        #elseif os(iOS)
        if #available(iOS 18.4, *), isSupported {
            return controllerStorage
        }
        #endif
        return nil
    }

    /// Stable Chrome Web Store IDs — extensions **and** themes (theme-only never hits the extension catalog).
    var installedChromeStoreIDs: [String] {
        var ids = Set(
            extensions.compactMap { item -> String? in
                guard let storeID = item.chromeStoreID?.lowercased(),
                      ChromeWebStoreAPI.isValidExtensionID(storeID) else { return nil }
                return storeID
            }
        )
        if let themeIDs = themeStore?.installedChromeStoreIDs {
            ids.formUnion(themeIDs)
        }
        return ids.sorted()
    }

    /// Firefox AMO slugs for store pages (extensions + themes).
    var installedFirefoxSlugs: [String] {
        var slugs = Set(
            extensions.compactMap { item -> String? in
                guard let slug = item.firefoxSlug?.lowercased(), !slug.isEmpty else { return nil }
                return slug
            }
        )
        if let themeSlugs = themeStore?.installedFirefoxSlugs {
            slugs.formUnion(themeSlugs)
        }
        return slugs.sorted()
    }

    func isInstalledFromChromeWebStore(extensionID: String) -> Bool {
        let id = extensionID.lowercased()
        return installedChromeStoreIDs.contains(id)
    }

    func isInstalledFromFirefoxAMO(slug: String) -> Bool {
        let key = slug.lowercased()
        return installedFirefoxSlugs.contains(key)
    }

    /// Remember which permissions the user allowed in the install review sheet.
    /// `directoryHint` is the Chrome id, Firefox slug, or package folder name being installed.
    func prepareInstallPermissionReview(allowed: [String], directoryHint: String?) {
        pendingAllowedPermissions = Set(allowed)
        pendingInstallDirectoryHint = directoryHint?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if pendingInstallDirectoryHint?.isEmpty == true {
            pendingInstallDirectoryHint = nil
        }
    }

    func clearPendingPermissionReview() {
        pendingAllowedPermissions = nil
        pendingInstallDirectoryHint = nil
    }

    /// Best-effort: Safari import matched by bundle id or normalized display name.
    func isInstalledFromSafari(bundleIdentifier: String) -> Bool {
        if bundleIdentifier.hasPrefix("known:") {
            let key = String(bundleIdentifier.dropFirst("known:".count))
            return extensions.contains {
                ExtensionStoreCatalog.normalizationKey(forName: $0.displayName) == key
                    && $0.chromeStoreID == nil
                    && $0.firefoxSlug == nil
            }
        }
        if let candidate = safariCandidates.first(where: { $0.bundleIdentifier == bundleIdentifier }) {
            let key = ExtensionStoreCatalog.normalizationKey(forName: candidate.displayName)
            return extensions.contains {
                ExtensionStoreCatalog.normalizationKey(forName: $0.displayName) == key
            }
        }
        return false
    }

    var extensionsDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("Oriel/Extensions", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func reloadFromDisk() async {
        #if os(macOS)
        if #available(macOS 15.4, *) { await reloadFromDiskImpl() }
        #elseif os(iOS)
        if #available(iOS 18.4, *) { await reloadFromDiskImpl() }
        #endif
    }

    func installFromPackage(at url: URL) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await installFromPackageImpl(url, preferredUniqueID: nil, chromeStoreID: nil, firefoxSlug: nil)
        }
        #elseif os(iOS)
        if #available(iOS 18.4, *) {
            await installFromPackageImpl(url, preferredUniqueID: nil, chromeStoreID: nil, firefoxSlug: nil)
        }
        #endif
    }

    /// Downloads a CRX from the Chrome Web Store and installs it.
    func installFromChromeWebStore(extensionID: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await installFromChromeWebStoreImpl(extensionID)
            return
        }
        #elseif os(iOS)
        if #available(iOS 18.4, *) {
            await installFromChromeWebStoreImpl(extensionID)
            return
        }
        #endif
        lastError = "Chrome Web Store install requires a newer OS with Oriel extensions."
    }

    /// Downloads a signed `.xpi` from addons.mozilla.org and installs it (extensions + themes).
    func installFromFirefoxAMO(slugOrID: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await installFromFirefoxAMOImpl(slugOrID)
            return
        }
        #elseif os(iOS)
        if #available(iOS 18.4, *) {
            await installFromFirefoxAMOImpl(slugOrID)
            return
        }
        #endif
        lastError = "Firefox add-on install requires a newer OS with Oriel extensions."
    }

    func setEnabled(_ enabled: Bool, id: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) { await setEnabledImpl(enabled, id: id) }
        #elseif os(iOS)
        if #available(iOS 18.4, *) { await setEnabledImpl(enabled, id: id) }
        #endif
    }

    func remove(id: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) { await removeImpl(id: id) }
        #elseif os(iOS)
        if #available(iOS 18.4, *) { await removeImpl(id: id) }
        #endif
    }

    /// Runs the extension’s browser action / popup (toolbar-style click).
    func openAction(for id: String) {
        #if os(macOS)
        if #available(macOS 15.4, *) { openActionImpl(id: id) }
        #elseif os(iOS)
        if #available(iOS 18.4, *) { openActionImpl(id: id) }
        #endif
    }

    /// Scans `/Applications` and `~/Applications` for Safari Web Extension packages.
    func refreshSafariCandidates() {
        #if os(macOS)
        isScanningSafari = true
        defer { isScanningSafari = false }
        safariCandidates = SafariWebExtensionImporter.discoverInstalledCandidates(fileManager: fileManager)
        if safariCandidates.isEmpty {
            statusMessage = "No Safari extension packages found in Applications."
        } else {
            let importable = safariCandidates.filter(\.isImportable).count
            statusMessage = "Found \(safariCandidates.count) Safari package(s); \(importable) can be imported."
        }
        #else
        lastError = "Scanning installed Safari extensions is available on macOS."
        #endif
    }

    /// Imports a discovered Safari Web Extension candidate into Oriel.
    func installSafariCandidate(_ candidate: SafariExtensionCandidate) async {
        guard candidate.isImportable else {
            lastError = candidate.statusDetail
            return
        }
        statusMessage = "Importing \(candidate.displayName)…"
        await installFromPackage(at: candidate.appexURL)
        if lastError == nil {
            statusMessage = "Imported \(candidate.displayName) from Safari."
        }
    }

    // MARK: - Shared implementation (macOS 15.4+ / iOS 18.4+)

    @available(macOS 15.4, iOS 18.4, *)
    private var controller: WKWebExtensionController? {
        controllerStorage as? WKWebExtensionController
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func reloadFromDiskImpl() async {
        lastError = nil
        guard let controller else { return }

        for context in Array(controller.extensionContexts) {
            try? controller.unload(context)
        }

        let catalog = dedupeCatalog(loadCatalog())
        saveCatalog(catalog)
        var loaded: [InstalledExtensionInfo] = []

        for entry in catalog {
            let folder = extensionsDirectory.appendingPathComponent(entry.directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: folder.path) else { continue }
            do {
                // Re-apply compat (e.g. force persistent:false) so older installs keep loading on iOS.
                ManifestCompatNormalizer.normalizePackage(at: folder)
                let webExtension = try await WKWebExtension(resourceBaseURL: folder)
                let context = WKWebExtensionContext(for: webExtension)
                context.uniqueIdentifier = entry.directoryName
                let applyPending = shouldApplyPendingReview(to: entry)
                var deniedThisLoad = deniedPermissionsByDirectory[entry.directoryName] ?? []
                for permission in webExtension.requestedPermissions {
                    let name = Self.permissionName(permission)
                    var deny = ExtensionCompatibility.blockedPermissions.contains(name)
                    if deniedThisLoad.contains(name) { deny = true }
                    if applyPending, let allowed = pendingAllowedPermissions, !allowed.contains(name) {
                        deny = true
                    }
                    if deny {
                        context.setPermissionStatus(.deniedExplicitly, for: permission)
                        deniedThisLoad.insert(name)
                    } else {
                        context.setPermissionStatus(.grantedExplicitly, for: permission)
                    }
                }
                if applyPending {
                    deniedPermissionsByDirectory[entry.directoryName] = deniedThisLoad
                }
                for pattern in webExtension.requestedPermissionMatchPatterns {
                    context.setPermissionStatus(.grantedExplicitly, for: pattern)
                }
                if entry.isEnabled {
                    try controller.load(context)
                }

                loaded.append(
                    InstalledExtensionInfo(
                        id: context.uniqueIdentifier,
                        displayName: webExtension.displayName
                            ?? webExtension.displayShortName
                            ?? entry.displayName,
                        version: webExtension.displayVersion ?? entry.version,
                        isEnabled: entry.isEnabled,
                        directoryName: entry.directoryName,
                        chromeStoreID: entry.chromeStoreID
                            ?? (ChromeWebStoreAPI.isValidExtensionID(entry.directoryName)
                                ? entry.directoryName
                                : nil),
                        firefoxSlug: entry.firefoxSlug
                    )
                )
            } catch {
                lastError = error.localizedDescription
            }
        }

        extensions = loaded.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        if pendingAllowedPermissions != nil {
            persistDeniedPermissions()
            clearPendingPermissionReview()
        }
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func installFromChromeWebStoreImpl(_ extensionID: String) async {
        lastError = nil
        statusMessage = nil
        let id = extensionID.lowercased()
        guard ChromeWebStoreAPI.isValidExtensionID(id) else {
            lastError = "That Chrome Web Store page does not look like an extension."
            return
        }

        if isInstalledFromChromeWebStore(extensionID: id) {
            statusMessage = "Updating…"
        }

        guard let downloadURL = ChromeWebStoreAPI.downloadURL(forExtensionID: id) else {
            lastError = "Could not build a download URL for this extension."
            return
        }

        isInstallingFromStore = true
        if statusMessage == nil {
            statusMessage = "Downloading from Chrome Web Store…"
        }
        defer { isInstallingFromStore = false }

        do {
            var request = URLRequest(url: downloadURL)
            request.setValue(UserAgentPolicy.chromeDesktop, forHTTPHeaderField: "User-Agent")
            request.setValue("https://chromewebstore.google.com/", forHTTPHeaderField: "Referer")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ExtensionError.storeDownloadFailed
            }
            guard data.count > 16 else { throw ExtensionError.storeDownloadFailed }
            let isCRX = data.starts(with: Array("Cr24".utf8))
            let isZIP = data.starts(with: [0x50, 0x4B, 0x03, 0x04])
            guard isCRX || isZIP else { throw ExtensionError.storeDownloadFailed }

            let fileExtension = isCRX ? "crx" : "zip"
            let tempPackage = fileManager.temporaryDirectory
                .appendingPathComponent("oriel-cws-\(id)-\(UUID().uuidString).\(fileExtension)")
            try data.write(to: tempPackage, options: .atomic)
            statusMessage = "Installing…"
            await installFromPackageImpl(tempPackage, preferredUniqueID: id, chromeStoreID: id, firefoxSlug: nil)
            try? fileManager.removeItem(at: tempPackage)

            if lastError == nil {
                statusMessage = statusMessage ?? "Installed from Chrome Web Store."
            } else {
                statusMessage = nil
            }
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusMessage = nil
        }
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func installFromFirefoxAMOImpl(_ slugOrID: String) async {
        lastError = nil
        statusMessage = nil
        let slug = slugOrID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else {
            lastError = "That Firefox add-on page does not look valid."
            return
        }
        guard let detailURL = FirefoxAddonsAPI.detailURL(forSlugOrID: slug) else {
            lastError = "Could not build a Firefox add-ons download URL."
            return
        }

        isInstallingFromStore = true
        statusMessage = "Downloading from Firefox Add-ons…"
        defer { isInstallingFromStore = false }

        do {
            var detailRequest = URLRequest(url: detailURL)
            detailRequest.setValue("OrielBrowser/1.0", forHTTPHeaderField: "User-Agent")
            let (detailData, detailResponse) = try await URLSession.shared.data(for: detailRequest)
            if let http = detailResponse as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ExtensionError.storeDownloadFailed
            }
            guard let xpiURL = FirefoxAddonsAPI.xpiURL(fromDetailJSON: detailData) else {
                throw ExtensionError.storeDownloadFailed
            }

            var xpiRequest = URLRequest(url: xpiURL)
            xpiRequest.setValue("OrielBrowser/1.0", forHTTPHeaderField: "User-Agent")
            xpiRequest.setValue("https://addons.mozilla.org/", forHTTPHeaderField: "Referer")
            let (data, response) = try await URLSession.shared.data(for: xpiRequest)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                throw ExtensionError.storeDownloadFailed
            }
            guard data.starts(with: [0x50, 0x4B, 0x03, 0x04]) else {
                throw ExtensionError.storeDownloadFailed
            }

            let tempPackage = fileManager.temporaryDirectory
                .appendingPathComponent("oriel-amo-\(slug)-\(UUID().uuidString).xpi")
            try data.write(to: tempPackage, options: .atomic)
            statusMessage = "Installing…"
            await installFromPackageImpl(
                tempPackage,
                preferredUniqueID: slug,
                chromeStoreID: nil,
                firefoxSlug: slug
            )
            try? fileManager.removeItem(at: tempPackage)

            if lastError == nil {
                let name = FirefoxAddonsAPI.displayName(fromDetailJSON: detailData)
                statusMessage = statusMessage
                    ?? (name.map { "Installed “\($0)” from Firefox Add-ons." }
                        ?? "Installed from Firefox Add-ons.")
            } else {
                statusMessage = nil
            }
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusMessage = nil
        }
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func installFromPackageImpl(
        _ url: URL,
        preferredUniqueID: String?,
        chromeStoreID: String?,
        firefoxSlug: String?
    ) async {
        lastError = nil
        do {
            let staging = try await stagePackage(at: url)
            let source = themeSource(
                for: url,
                chromeStoreID: chromeStoreID,
                firefoxSlug: firefoxSlug
            )

            // Static themes (Chrome/Firefox/Safari): apply to Oriel chrome.
            if ExtensionThemeParser.manifestContainsTheme(at: staging),
               let themeStore {
                do {
                    let (theme, isThemeOnly) = try themeStore.importStagedPackage(
                        at: staging,
                        source: source,
                        preferredID: preferredUniqueID ?? firefoxSlug ?? chromeStoreID
                    )
                    if isThemeOnly {
                        try? fileManager.removeItem(at: staging)
                        statusMessage = "Applied \(theme.sourceLabel) theme “\(theme.displayName)”."
                        return
                    }
                    statusMessage = "Installed \(theme.sourceLabel) theme “\(theme.displayName)”."
                } catch {
                    // Hybrid / parse failure — still try loading as a normal WebExtension.
                }
            }

            let webExtension = try await WKWebExtension(resourceBaseURL: staging)
            let context = WKWebExtensionContext(for: webExtension)
            if let preferredUniqueID, !preferredUniqueID.isEmpty {
                context.uniqueIdentifier = preferredUniqueID
            }
            let extensionID = context.uniqueIdentifier

            let destination = extensionsDirectory.appendingPathComponent(extensionID, isDirectory: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: staging, to: destination)

            var catalog = dedupeCatalog(loadCatalog())
            let resolvedChromeID = chromeStoreID ?? preferredUniqueID.flatMap {
                ChromeWebStoreAPI.isValidExtensionID($0) ? $0 : nil
            }
            let resolvedFirefoxSlug = firefoxSlug?.lowercased()
            catalog.removeAll {
                $0.directoryName == extensionID
                    || ($0.chromeStoreID != nil && $0.chromeStoreID == resolvedChromeID)
                    || ($0.chromeStoreID != nil && $0.chromeStoreID == preferredUniqueID)
                    || ($0.firefoxSlug != nil && $0.firefoxSlug?.lowercased() == resolvedFirefoxSlug)
            }
            catalog.append(
                CatalogEntry(
                    directoryName: extensionID,
                    displayName: webExtension.displayName ?? webExtension.displayShortName ?? "Extension",
                    version: webExtension.displayVersion ?? "—",
                    isEnabled: true,
                    chromeStoreID: resolvedChromeID,
                    firefoxSlug: resolvedFirefoxSlug
                )
            )
            saveCatalog(catalog)
            await reloadFromDiskImpl()
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func themeSource(
        for url: URL,
        chromeStoreID: String?,
        firefoxSlug: String?
    ) -> ExtensionThemeSource {
        if chromeStoreID != nil { return .chrome }
        if firefoxSlug != nil { return .firefox }
        switch url.pathExtension.lowercased() {
        case "appex": return .safari
        case "xpi": return .firefox
        case "crx": return .chrome
        default: return .file
        }
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func setEnabledImpl(_ enabled: Bool, id: String) async {
        guard let info = extensions.first(where: { $0.id == id }) else { return }
        var catalog = loadCatalog()
        guard let index = catalog.firstIndex(where: { $0.directoryName == info.directoryName }) else { return }
        catalog[index].isEnabled = enabled
        saveCatalog(catalog)
        await reloadFromDiskImpl()
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func removeImpl(id: String) async {
        guard let info = extensions.first(where: { $0.id == id }) else { return }
        let folder = extensionsDirectory.appendingPathComponent(info.directoryName, isDirectory: true)
        try? fileManager.removeItem(at: folder)
        var catalog = loadCatalog()
        catalog.removeAll {
            $0.directoryName == info.directoryName
                || ($0.chromeStoreID != nil && $0.chromeStoreID == info.chromeStoreID)
        }
        saveCatalog(catalog)
        await reloadFromDiskImpl()
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func openActionImpl(id: String) {
        lastError = nil
        guard let info = extensions.first(where: { $0.id == id }) else { return }
        guard info.isEnabled else {
            lastError = "Enable \(info.displayName) before opening it."
            return
        }
        guard let context = controller?.extensionContexts.first(where: { $0.uniqueIdentifier == id }) else {
            lastError = "Could not find \(info.displayName). Try toggling it off and on."
            return
        }
        context.performAction(for: nil)
        statusMessage = "Opened \(info.displayName)."
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func stagePackage(at url: URL) async throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("oriel-ext-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ExtensionError.invalidPackage
        }

        let ext = url.pathExtension.lowercased()

        // Safari Web Extension `.appex`: peel WebExtension resources out of the appex wrapper.
        if ext == "appex" {
            do {
                try SafariWebExtensionImporter.extractWebExtensionResources(
                    from: url,
                    to: tempRoot,
                    fileManager: fileManager
                )
                return tempRoot
            } catch let safariError as SafariImportError {
                // Fall back to WebKit’s native appex loader, then persist extracted resources.
                if case .missingManifestInAppex = safariError,
                   let staged = try await stageFromAppExtensionBundle(url, into: tempRoot) {
                    return staged
                }
                throw safariError
            }
        }

        if isDirectory.boolValue || ext == "bundle" {
            // Prefer Safari-aware extraction when the folder looks like a Safari Web Extension.
            let candidate = SafariWebExtensionImporter.classify(appexURL: url)
            if candidate.kind == .legacySafariAppExtension {
                throw SafariImportError.legacySafariOnly
            }
            if candidate.kind == .contentBlocker {
                throw SafariImportError.contentBlockerUnsupported
            }
            if candidate.manifestURL != nil || SafariWebExtensionImporter.findManifest(in: url) != nil {
                try SafariWebExtensionImporter.extractWebExtensionResources(
                    from: url,
                    to: tempRoot,
                    fileManager: fileManager
                )
                return tempRoot
            }

            for item in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
                try fileManager.copyItem(
                    at: item,
                    to: tempRoot.appendingPathComponent(item.lastPathComponent)
                )
            }
        } else {
            // `.xpi` is a ZIP (Firefox / AMO). `.crx` is Chrome’s signed ZIP.
            guard ext == "zip" || ext == "crx" || ext == "xpi" else { throw ExtensionError.unsupportedFormat }
            try unzip(url, to: tempRoot)
        }

        guard let manifest = findManifest(in: tempRoot) else {
            throw ExtensionError.missingManifest
        }
        // Prefer throwing normalize failures over silently loading a persistent background on iOS.
        try ManifestCompatNormalizer.normalize(at: manifest)
        ManifestCompatNormalizer.normalizePackage(at: tempRoot)

        let root = manifest.deletingLastPathComponent()
        if root != tempRoot {
            let promoted = fileManager.temporaryDirectory
                .appendingPathComponent("oriel-ext-promoted-\(UUID().uuidString)", isDirectory: true)
            try fileManager.moveItem(at: root, to: promoted)
            try? fileManager.removeItem(at: tempRoot)
            if let promotedManifest = findManifest(in: promoted) {
                try ManifestCompatNormalizer.normalize(at: promotedManifest)
            }
            ManifestCompatNormalizer.normalizePackage(at: promoted)
            return promoted
        }
        return tempRoot
    }

    /// Last-resort path: let WebKit read the Safari appex, then copy its resource tree for persistence.
    @available(macOS 15.4, iOS 18.4, *)
    private func stageFromAppExtensionBundle(_ appexURL: URL, into tempRoot: URL) async throws -> URL? {
        guard let bundle = Bundle(url: appexURL) else { return nil }
        // Validate the package with WebKit’s Safari appex loader.
        _ = try await WKWebExtension(appExtensionBundle: bundle)

        // Persist a resource tree Oriel can reload after quit. Prefer Resources/ when present.
        let resourceCandidates = [
            appexURL.appendingPathComponent("Contents/Resources", isDirectory: true),
            appexURL.appendingPathComponent("Resources", isDirectory: true),
            appexURL
        ]
        for candidate in resourceCandidates {
            if SafariWebExtensionImporter.findManifest(in: candidate) != nil {
                try? fileManager.removeItem(at: tempRoot)
                try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)
                try SafariWebExtensionImporter.extractWebExtensionResources(
                    from: candidate,
                    to: tempRoot,
                    fileManager: fileManager
                )
                return tempRoot
            }
        }
        return nil
    }

    private func unzip(_ zipURL: URL, to destination: URL) throws {
        var source = zipURL
        var tempZip: URL?
        if zipURL.pathExtension.lowercased() == "crx" {
            let data = try stripCRXHeader(from: Data(contentsOf: zipURL))
            let out = destination.appendingPathComponent("package.zip")
            try data.write(to: out)
            source = out
            tempZip = out
        }

        do {
            try fileManager.unzipItem(at: source, to: destination)
        } catch {
            throw ExtensionError.unzipFailed
        }
        if let tempZip { try? fileManager.removeItem(at: tempZip) }
    }

    private func stripCRXHeader(from data: Data) throws -> Data {
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return data }
        guard data.count > 16 else { throw ExtensionError.invalidPackage }
        let magic = String(data: data.prefix(4), encoding: .ascii) ?? ""
        guard magic == "Cr24" else { throw ExtensionError.invalidPackage }
        let version = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        if version >= 3 {
            let headerSize = Int(data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
            let offset = 12 + headerSize
            guard data.count > offset else { throw ExtensionError.invalidPackage }
            return data.subdata(in: offset..<data.count)
        }
        let pubKeyLen = Int(data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        let sigLen = Int(data.subdata(in: 12..<16).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
        let offset = 16 + pubKeyLen + sigLen
        guard data.count > offset else { throw ExtensionError.invalidPackage }
        return data.subdata(in: offset..<data.count)
    }

    private func findManifest(in root: URL) -> URL? {
        let direct = root.appendingPathComponent("manifest.json")
        if fileManager.fileExists(atPath: direct.path) { return direct }
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        for case let fileURL as URL in enumerator where fileURL.lastPathComponent == "manifest.json" {
            return fileURL
        }
        return nil
    }

    private func dedupeCatalog(_ entries: [CatalogEntry]) -> [CatalogEntry] {
        var result: [CatalogEntry] = []
        var seenDirectories = Set<String>()
        var seenStoreIDs = Set<String>()
        var seenFirefoxSlugs = Set<String>()
        for entry in entries.reversed() {
            if seenDirectories.contains(entry.directoryName) { continue }
            if let storeID = entry.chromeStoreID, seenStoreIDs.contains(storeID) { continue }
            if let slug = entry.firefoxSlug?.lowercased(), seenFirefoxSlugs.contains(slug) { continue }
            seenDirectories.insert(entry.directoryName)
            if let storeID = entry.chromeStoreID { seenStoreIDs.insert(storeID) }
            if let slug = entry.firefoxSlug?.lowercased() { seenFirefoxSlugs.insert(slug) }
            result.append(entry)
        }
        return result.reversed()
    }

    private struct CatalogEntry: Codable, Equatable {
        var directoryName: String
        var displayName: String
        var version: String
        var isEnabled: Bool
        var chromeStoreID: String?
        var firefoxSlug: String?
    }

    private func loadCatalog() -> [CatalogEntry] {
        let url = extensionsDirectory.appendingPathComponent(catalogName)
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([CatalogEntry].self, from: data) else {
            return []
        }
        return decoded
    }

    private func saveCatalog(_ entries: [CatalogEntry]) {
        let url = extensionsDirectory.appendingPathComponent(catalogName)
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? data.write(to: url, options: .atomic)
    }

    @available(macOS 15.4, iOS 18.4, *)
    private func shouldApplyPendingReview(to entry: CatalogEntry) -> Bool {
        guard pendingAllowedPermissions != nil else { return false }
        guard let hint = pendingInstallDirectoryHint, !hint.isEmpty else {
            // No hint: apply only to the newest catalog entry (last install).
            return entry.directoryName == catalogNewestDirectoryName()
        }
        if entry.directoryName.lowercased() == hint { return true }
        if entry.chromeStoreID?.lowercased() == hint { return true }
        if entry.firefoxSlug?.lowercased() == hint { return true }
        return false
    }

    private func catalogNewestDirectoryName() -> String? {
        loadCatalog().last?.directoryName
    }

    @available(macOS 15.4, iOS 18.4, *)
    private static func permissionName(_ permission: WKWebExtension.Permission) -> String {
        if let raw = Mirror(reflecting: permission).descendant("rawValue") as? String {
            return raw
        }
        return String(describing: permission)
    }

    private static func loadDeniedPermissions(fileName: String) -> [String: Set<String>] {
        guard let loaded = try? JSONFileStore.load([String: [String]].self, from: fileName) else {
            return [:]
        }
        var result: [String: Set<String>] = [:]
        for (key, values) in loaded {
            result[key] = Set(values)
        }
        return result
    }

    private func persistDeniedPermissions() {
        var payload: [String: [String]] = [:]
        for (key, values) in deniedPermissionsByDirectory {
            payload[key] = values.sorted()
        }
        try? JSONFileStore.save(payload, to: deniedPermissionsFileName)
    }
}

#if os(macOS)
/// Presents extension action popups via `NSPopover`.
@available(macOS 15.4, *)
final class WebExtensionHost: NSObject, WKWebExtensionControllerDelegate {
    func webExtensionController(
        _ controller: WKWebExtensionController,
        presentActionPopup action: WKWebExtension.Action,
        for extensionContext: WKWebExtensionContext
    ) async throws {
        guard action.presentsPopup, let popover = action.popupPopover else { return }
        await MainActor.run {
            guard let anchor = NSApp.keyWindow?.contentView else { return }
            if popover.isShown {
                popover.close()
                return
            }
            let rect = NSRect(
                x: anchor.bounds.midX - 12,
                y: anchor.bounds.maxY - 48,
                width: 24,
                height: 24
            )
            popover.show(relativeTo: rect, of: anchor, preferredEdge: .minY)
        }
    }
}
#elseif os(iOS)
/// Presents extension action popups as sheets on iPhone/iPad.
@available(iOS 18.4, *)
final class WebExtensionHost: NSObject, WKWebExtensionControllerDelegate {
    func webExtensionController(
        _ controller: WKWebExtensionController,
        presentActionPopup action: WKWebExtension.Action,
        for extensionContext: WKWebExtensionContext
    ) async throws {
        guard action.presentsPopup, let popup = action.popupViewController else { return }
        await MainActor.run {
            guard let presenter = Self.topViewController() else { return }
            if popup.presentingViewController != nil {
                popup.dismiss(animated: true)
                return
            }
            popup.modalPresentationStyle = .pageSheet
            presenter.present(popup, animated: true)
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = scenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
            ?? scenes.flatMap(\.windows).first
        guard var top = window?.rootViewController else { return nil }
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
}
#endif

enum ExtensionError: LocalizedError {
    case invalidPackage
    case unsupportedFormat
    case missingManifest
    case unzipFailed
    case storeDownloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidPackage: "This package could not be read as a web extension."
        case .unsupportedFormat:
            "Use an unpacked folder with manifest.json, a .zip / .crx / .xpi, or a Safari Web Extension .appex that still contains WebExtension resources."
        case .missingManifest:
            "No manifest.json found. Safari Web Extensions need a WebExtension manifest; legacy native Safari App Extensions cannot run in Oriel."
        case .unzipFailed: "Could not extract the extension archive."
        case .storeDownloadFailed: "Could not download this extension from the store."
        }
    }
}
