import SwiftUI
#if os(iOS)
import QuickLook
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DownloadsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @State private var previewURL: URL?
    #endif

    var body: some View {
        NavigationStack {
            Group {
                if environment.downloads.items.isEmpty {
                    ContentUnavailableView(
                        "No Downloads",
                        systemImage: "arrow.down.circle",
                        description: Text("Downloadable files from pages will appear here.")
                    )
                } else {
                    List {
                        ForEach(environment.downloads.items) { item in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(item.fileName)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(statusText(item))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if item.state == .downloading {
                                    ProgressView(value: item.progress)
                                }
                                if let error = item.errorMessage, item.state == .failed || item.state == .cancelled {
                                    Text(error)
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                                HStack {
                                    if item.state == .downloading {
                                        Button("Cancel") { environment.downloads.cancel(item.id) }
                                    }
                                    if item.state == .failed || item.state == .cancelled {
                                        Button("Retry") { environment.downloads.retry(item.id) }
                                    }
                                    #if os(macOS)
                                    if item.state == .completed, let url = item.destinationURL {
                                        Button("Show in Finder") {
                                            NSWorkspace.shared.activateFileViewerSelecting([url])
                                        }
                                    }
                                    #elseif os(iOS)
                                    if item.state == .completed, let url = item.destinationURL {
                                        ShareLink(item: url) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                        Button("Open") {
                                            previewURL = url
                                        }
                                    }
                                    #endif
                                    Spacer()
                                    Button("Remove", role: .destructive) {
                                        environment.downloads.remove(item.id)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Downloads")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: Binding(
                get: { previewURL.map(IdentifiableURL.init) },
                set: { previewURL = $0?.url }
            )) { item in
                QuickLookPreview(url: item.url)
                    .ignoresSafeArea()
            }
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func statusText(_ item: DownloadItem) -> String {
        switch item.state {
        case .downloading: return "Downloading…"
        case .completed: return "Done"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
}

#if os(iOS)
private struct IdentifiableURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

private struct QuickLookPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        init(url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> any QLPreviewItem {
            url as NSURL
        }
    }
}
#endif
