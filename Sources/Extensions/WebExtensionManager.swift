import Foundation
import Observation
import WebKit
import ZIPFoundation
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

    private var controllerStorage: AnyObject?
    private var hostStorage: AnyObject?
    private let fileManager = FileManager.default
    private let catalogName = "extensions-catalog.json"

    init() {
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

    /// Stable Chrome Web Store IDs only (never WebKit-generated unique IDs).
    var installedChromeStoreIDs: [String] {
        Array(
            Set(
                extensions.compactMap { item -> String? in
                    guard let storeID = item.chromeStoreID?.lowercased(),
                          ChromeWebStoreAPI.isValidExtensionID(storeID) else { return nil }
                    return storeID
                }
            )
        ).sorted()
    }

    func isInstalledFromChromeWebStore(extensionID: String) -> Bool {
        let id = extensionID.lowercased()
        return installedChromeStoreIDs.contains(id)
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
            await installFromPackageImpl(url, preferredUniqueID: nil, chromeStoreID: nil)
        }
        #elseif os(iOS)
        if #available(iOS 18.4, *) {
            await installFromPackageImpl(url, preferredUniqueID: nil, chromeStoreID: nil)
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

        var catalog = dedupeCatalog(loadCatalog())
        saveCatalog(catalog)
        var loaded: [InstalledExtensionInfo] = []

        for entry in catalog {
            let folder = extensionsDirectory.appendingPathComponent(entry.directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: folder.path) else { continue }
            do {
                let webExtension = try await WKWebExtension(resourceBaseURL: folder)
                let context = WKWebExtensionContext(for: webExtension)
                context.uniqueIdentifier = entry.directoryName
                for permission in webExtension.requestedPermissions {
                    context.setPermissionStatus(.grantedExplicitly, for: permission)
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
                                : nil)
                    )
                )
            } catch {
                lastError = error.localizedDescription
            }
        }

        extensions = loaded.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
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
            await installFromPackageImpl(tempPackage, preferredUniqueID: id, chromeStoreID: id)
            try? fileManager.removeItem(at: tempPackage)

            if lastError == nil {
                statusMessage = "Installed from Chrome Web Store."
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
        chromeStoreID: String?
    ) async {
        lastError = nil
        do {
            let staging = try stagePackage(at: url)
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
            catalog.removeAll {
                $0.directoryName == extensionID
                    || ($0.chromeStoreID != nil && $0.chromeStoreID == chromeStoreID)
                    || ($0.chromeStoreID != nil && $0.chromeStoreID == preferredUniqueID)
            }
            catalog.append(
                CatalogEntry(
                    directoryName: extensionID,
                    displayName: webExtension.displayName ?? webExtension.displayShortName ?? "Extension",
                    version: webExtension.displayVersion ?? "—",
                    isEnabled: true,
                    chromeStoreID: chromeStoreID ?? preferredUniqueID.flatMap {
                        ChromeWebStoreAPI.isValidExtensionID($0) ? $0 : nil
                    }
                )
            )
            saveCatalog(catalog)
            await reloadFromDiskImpl()
        } catch {
            lastError = error.localizedDescription
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
    private func stagePackage(at url: URL) throws -> URL {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let tempRoot = fileManager.temporaryDirectory
            .appendingPathComponent("oriel-ext-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: tempRoot, withIntermediateDirectories: true)

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            throw ExtensionError.invalidPackage
        }

        if isDirectory.boolValue || ["appex", "bundle"].contains(url.pathExtension.lowercased()) {
            // Copy package contents (folder or Safari .appex bundle).
            let sourceRoot = url
            for item in try fileManager.contentsOfDirectory(at: sourceRoot, includingPropertiesForKeys: nil) {
                try fileManager.copyItem(
                    at: item,
                    to: tempRoot.appendingPathComponent(item.lastPathComponent)
                )
            }
        } else {
            let ext = url.pathExtension.lowercased()
            guard ext == "zip" || ext == "crx" else { throw ExtensionError.unsupportedFormat }
            try unzip(url, to: tempRoot)
        }

        guard let manifest = findManifest(in: tempRoot) else {
            throw ExtensionError.missingManifest
        }
        let root = manifest.deletingLastPathComponent()
        if root != tempRoot {
            let promoted = fileManager.temporaryDirectory
                .appendingPathComponent("oriel-ext-promoted-\(UUID().uuidString)", isDirectory: true)
            try fileManager.moveItem(at: root, to: promoted)
            try? fileManager.removeItem(at: tempRoot)
            return promoted
        }
        return tempRoot
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
        for entry in entries.reversed() {
            if seenDirectories.contains(entry.directoryName) { continue }
            if let storeID = entry.chromeStoreID, seenStoreIDs.contains(storeID) { continue }
            seenDirectories.insert(entry.directoryName)
            if let storeID = entry.chromeStoreID { seenStoreIDs.insert(storeID) }
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
            "Use an unpacked folder with manifest.json, a .zip / .crx package, or a Safari Web Extension source folder. Safari App Store .appex installs are not transferable."
        case .missingManifest:
            "No manifest.json found. Safari App Store extensions are not compatible — use a WebExtension package instead."
        case .unzipFailed: "Could not extract the extension archive."
        case .storeDownloadFailed: "Could not download this extension from the Chrome Web Store."
        }
    }
}
