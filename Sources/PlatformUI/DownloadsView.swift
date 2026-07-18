import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct DownloadsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

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
                                            UIApplication.shared.open(url)
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
        case .downloading: "Downloading \(Int(item.progress * 100))%"
        case .completed: "Completed"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }
}
