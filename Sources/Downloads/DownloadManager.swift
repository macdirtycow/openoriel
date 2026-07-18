import Foundation
import Observation
import WebKit

enum DownloadState: String, Codable, Sendable {
    case downloading
    case completed
    case failed
    case cancelled
}

struct DownloadItem: Identifiable, Equatable, Sendable {
    let id: UUID
    var fileName: String
    var sourceURL: URL?
    var destinationURL: URL?
    var progress: Double
    var state: DownloadState
    var errorMessage: String?
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fileName: String,
        sourceURL: URL? = nil,
        destinationURL: URL? = nil,
        progress: Double = 0,
        state: DownloadState = .downloading,
        errorMessage: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.fileName = fileName
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.progress = progress
        self.state = state
        self.errorMessage = errorMessage
        self.updatedAt = updatedAt
    }
}

@Observable
@MainActor
final class DownloadManager {
    private(set) var items: [DownloadItem] = []
    private var activeDownloads: [UUID: URLSessionDownloadTask] = [:]
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        config.httpCookieAcceptPolicy = .always
        session = URLSession(configuration: config)
    }

    var hasActiveDownloads: Bool {
        items.contains { $0.state == .downloading }
    }

    func enqueue(url: URL, suggestedFileName: String?) {
        let name = suggestedFileName?.isEmpty == false
            ? suggestedFileName!
            : (url.lastPathComponent.isEmpty ? "download" : url.lastPathComponent)
        let item = DownloadItem(fileName: name, sourceURL: url, progress: 0, state: .downloading)
        items.insert(item, at: 0)
        start(itemID: item.id)
    }

    func cancel(_ id: UUID) {
        activeDownloads[id]?.cancel()
        activeDownloads[id] = nil
        update(id) { item in
            item.state = .cancelled
            item.errorMessage = "Cancelled"
            item.updatedAt = .now
        }
    }

    func retry(_ id: UUID) {
        guard let item = items.first(where: { $0.id == id }), let url = item.sourceURL else { return }
        update(id) { item in
            item.state = .downloading
            item.progress = 0
            item.errorMessage = nil
            item.updatedAt = .now
        }
        start(itemID: id, url: url)
    }

    func remove(_ id: UUID) {
        cancel(id)
        items.removeAll { $0.id == id }
    }

    func clearAll() {
        for item in items where item.state == .downloading {
            cancel(item.id)
        }
        items.removeAll()
    }

    private func start(itemID: UUID, url: URL? = nil) {
        guard let source = url ?? items.first(where: { $0.id == itemID })?.sourceURL else { return }
        Task { @MainActor in
            await Self.copyWebKitCookies(into: HTTPCookieStorage.shared)
            guard items.contains(where: { $0.id == itemID && $0.state == .downloading }) else { return }

            let task = session.downloadTask(with: source) { [weak self] tempURL, response, error in
                Task { @MainActor in
                    guard let self else { return }
                    self.activeDownloads[itemID] = nil
                    if let error {
                        self.update(itemID) { item in
                            item.state = .failed
                            item.errorMessage = error.localizedDescription
                            item.updatedAt = .now
                        }
                        return
                    }
                    guard let tempURL else {
                        self.update(itemID) { item in
                            item.state = .failed
                            item.errorMessage = "Download produced no file."
                            item.updatedAt = .now
                        }
                        return
                    }
                    do {
                        let destination = try self.moveToDownloads(
                            from: tempURL,
                            preferredName: self.items.first(where: { $0.id == itemID })?.fileName
                                ?? response?.suggestedFilename
                                ?? source.lastPathComponent
                        )
                        self.update(itemID) { item in
                            item.state = .completed
                            item.progress = 1
                            item.destinationURL = destination
                            item.fileName = destination.lastPathComponent
                            item.errorMessage = nil
                            item.updatedAt = .now
                        }
                    } catch {
                        self.update(itemID) { item in
                            item.state = .failed
                            item.errorMessage = error.localizedDescription
                            item.updatedAt = .now
                        }
                    }
                }
            }
            activeDownloads[itemID] = task
            task.resume()
            Task { @MainActor in
                while let task = activeDownloads[itemID] {
                    let progress = task.progress.fractionCompleted
                    update(itemID) { item in
                        item.progress = progress
                        item.updatedAt = .now
                    }
                    try? await Task.sleep(nanoseconds: 250_000_000)
                }
            }
        }
    }

    /// Bridge WKWebsiteDataStore cookies into URLSession so authenticated downloads work.
    private static func copyWebKitCookies(into storage: HTTPCookieStorage) async {
        let cookies: [HTTPCookie] = await withCheckedContinuation { continuation in
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        for cookie in cookies {
            storage.setCookie(cookie)
        }
    }

    private func update(_ id: UUID, mutate: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        mutate(&item)
        items[index] = item
    }

    private func moveToDownloads(from tempURL: URL, preferredName: String?) throws -> URL {
        #if os(iOS)
        // App Documents is shareable/visible via Files; Downloads is not always accessible on iOS.
        let downloads = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #else
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #endif
        let baseName = preferredName?.isEmpty == false ? preferredName! : tempURL.lastPathComponent
        var destination = downloads.appendingPathComponent(baseName)
        var counter = 1
        while FileManager.default.fileExists(atPath: destination.path) {
            let stem = (baseName as NSString).deletingPathExtension
            let ext = (baseName as NSString).pathExtension
            let suffix = ext.isEmpty ? "\(stem)-\(counter)" : "\(stem)-\(counter).\(ext)"
            destination = downloads.appendingPathComponent(suffix)
            counter += 1
        }
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }
}
