import Foundation
import Observation
import WebKit

struct InstalledExtensionInfo: Identifiable, Equatable, Sendable {
    let id: String
    var displayName: String
    var version: String
    var isEnabled: Bool
    var directoryName: String
}

/// Loads Chrome/Firefox-style WebExtensions via Apple’s `WKWebExtension` (macOS 15.4+).
@Observable
@MainActor
final class WebExtensionManager {
    private(set) var extensions: [InstalledExtensionInfo] = []
    private(set) var lastError: String?
    private(set) var isSupported: Bool = false
    private(set) var statusMessage: String?
    private(set) var isInstallingFromStore = false

    private var controllerStorage: AnyObject?
    private let fileManager = FileManager.default
    private let catalogName = "extensions-catalog.json"

    init() {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            isSupported = true
            controllerStorage = WKWebExtensionController()
            Task { await reloadFromDisk() }
        } else {
            isSupported = false
            lastError = "Web extensions require macOS 15.4 or later."
        }
        #else
        isSupported = false
        lastError = "Chrome-style web extensions are not available in Oriel on iPhone and iPad."
        #endif
    }

    /// Attached to normal-tab `WKWebViewConfiguration` when supported.
    var webExtensionControllerForConfiguration: AnyObject? {
        #if os(macOS)
        if #available(macOS 15.4, *), isSupported {
            return controllerStorage
        }
        #endif
        return nil
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
        if #available(macOS 15.4, *) {
            await reloadFromDiskMac()
        }
        #endif
    }

    func installFromPackage(at url: URL) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await installFromPackageMac(url)
        }
        #endif
    }

    /// Downloads a CRX from the Chrome Web Store (same endpoint Chromium/Brave use) and installs it.
    func installFromChromeWebStore(extensionID: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await installFromChromeWebStoreMac(extensionID)
        }
        #else
        lastError = "Chrome Web Store install requires macOS 15.4+ with Oriel extensions."
        #endif
    }

    func setEnabled(_ enabled: Bool, id: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await setEnabledMac(enabled, id: id)
        }
        #endif
    }

    func remove(id: String) async {
        #if os(macOS)
        if #available(macOS 15.4, *) {
            await removeMac(id: id)
        }
        #endif
    }

    #if os(macOS)
    @available(macOS 15.4, *)
    private var controller: WKWebExtensionController? {
        controllerStorage as? WKWebExtensionController
    }

    @available(macOS 15.4, *)
    private func reloadFromDiskMac() async {
        lastError = nil
        guard let controller else { return }

        for context in Array(controller.extensionContexts) {
            try? controller.unload(context)
        }

        let catalog = loadCatalog()
        var loaded: [InstalledExtensionInfo] = []

        for entry in catalog {
            let folder = extensionsDirectory.appendingPathComponent(entry.directoryName, isDirectory: true)
            guard fileManager.fileExists(atPath: folder.path) else { continue }
            do {
                let webExtension = try await WKWebExtension(resourceBaseURL: folder)
                let context = WKWebExtensionContext(for: webExtension)
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
                        directoryName: entry.directoryName
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

    @available(macOS 15.4, *)
    private func installFromChromeWebStoreMac(_ extensionID: String) async {
        lastError = nil
        statusMessage = nil
        let id = extensionID.lowercased()
        guard ChromeWebStoreAPI.isValidExtensionID(id) else {
            lastError = "That Chrome Web Store page does not look like an extension."
            return
        }
        guard let downloadURL = ChromeWebStoreAPI.downloadURL(forExtensionID: id) else {
            lastError = "Could not build a download URL for this extension."
            return
        }

        isInstallingFromStore = true
        statusMessage = "Downloading from Chrome Web Store…"
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

            let tempCRX = fileManager.temporaryDirectory
                .appendingPathComponent("oriel-cws-\(id)-\(UUID().uuidString).crx")
            try data.write(to: tempCRX, options: .atomic)
            statusMessage = "Installing…"
            await installFromPackageMac(tempCRX)
            try? fileManager.removeItem(at: tempCRX)

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

    @available(macOS 15.4, *)
    private func installFromPackageMac(_ url: URL) async {
        lastError = nil
        do {
            let staging = try stagePackage(at: url)
            let webExtension = try await WKWebExtension(resourceBaseURL: staging)
            let context = WKWebExtensionContext(for: webExtension)
            let extensionID = context.uniqueIdentifier

            let destination = extensionsDirectory.appendingPathComponent(extensionID, isDirectory: true)
            if fileManager.fileExists(atPath: destination.path) {
                try fileManager.removeItem(at: destination)
            }
            try fileManager.moveItem(at: staging, to: destination)

            var catalog = loadCatalog()
            catalog.removeAll { $0.directoryName == extensionID }
            catalog.append(
                CatalogEntry(
                    directoryName: extensionID,
                    displayName: webExtension.displayName ?? webExtension.displayShortName ?? "Extension",
                    version: webExtension.displayVersion ?? "—",
                    isEnabled: true
                )
            )
            saveCatalog(catalog)
            await reloadFromDiskMac()
        } catch {
            lastError = error.localizedDescription
        }
    }

    @available(macOS 15.4, *)
    private func setEnabledMac(_ enabled: Bool, id: String) async {
        guard let info = extensions.first(where: { $0.id == id }) else { return }
        var catalog = loadCatalog()
        guard let index = catalog.firstIndex(where: { $0.directoryName == info.directoryName }) else { return }
        catalog[index].isEnabled = enabled
        saveCatalog(catalog)
        await reloadFromDiskMac()
    }

    @available(macOS 15.4, *)
    private func removeMac(id: String) async {
        guard let info = extensions.first(where: { $0.id == id }) else { return }
        let folder = extensionsDirectory.appendingPathComponent(info.directoryName, isDirectory: true)
        try? fileManager.removeItem(at: folder)
        var catalog = loadCatalog()
        catalog.removeAll { $0.directoryName == info.directoryName }
        saveCatalog(catalog)
        await reloadFromDiskMac()
    }

    @available(macOS 15.4, *)
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

        if isDirectory.boolValue {
            for item in try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) {
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

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", source.path, "-d", destination.path]
        try process.run()
        process.waitUntilExit()
        if let tempZip { try? fileManager.removeItem(at: tempZip) }
        guard process.terminationStatus == 0 else { throw ExtensionError.unzipFailed }
    }

    private func stripCRXHeader(from data: Data) throws -> Data {
        if data.starts(with: [0x50, 0x4B, 0x03, 0x04]) { return data }
        guard data.count > 16 else { throw ExtensionError.invalidPackage }
        let magic = String(data: data.prefix(4), encoding: .ascii) ?? ""
        guard magic == "Cr24" else { throw ExtensionError.invalidPackage }
        // CRX3: magic(4) + version(4) + headerLength(4) + header + zip
        let version = data.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        if version >= 3 {
            let headerSize = Int(data.subdata(in: 8..<12).withUnsafeBytes { $0.load(as: UInt32.self).littleEndian })
            let offset = 12 + headerSize
            guard data.count > offset else { throw ExtensionError.invalidPackage }
            return data.subdata(in: offset..<data.count)
        }
        // CRX2
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
    #endif

    private struct CatalogEntry: Codable, Equatable {
        var directoryName: String
        var displayName: String
        var version: String
        var isEnabled: Bool
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

enum ExtensionError: LocalizedError {
    case invalidPackage
    case unsupportedFormat
    case missingManifest
    case unzipFailed
    case storeDownloadFailed

    var errorDescription: String? {
        switch self {
        case .invalidPackage: "This package could not be read as a web extension."
        case .unsupportedFormat: "Use an unpacked folder, .zip, or .crx extension package."
        case .missingManifest: "No manifest.json found in the package."
        case .unzipFailed: "Could not extract the extension archive."
        case .storeDownloadFailed: "Could not download this extension from the Chrome Web Store."
        }
    }
}
