import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct BookmarksView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var importMessage: String?

    private var results: [Bookmark] {
        environment.bookmarks.search(query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView(
                        "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text("Bookmark the current page, or import an HTML export from another browser.")
                    )
                } else {
                    List {
                        ForEach(results) { bookmark in
                            Button {
                                if let url = bookmark.url {
                                    environment.tabs.activeTab?.load(url)
                                    dismiss()
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    FaviconImage(pageURL: bookmark.url, size: 18)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bookmark.title)
                                            .foregroundStyle(.primary)
                                        Text(bookmark.urlString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                environment.bookmarks.remove(id: results[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $query, prompt: "Search bookmarks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Import…") {
                        importBookmarks()
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let importMessage {
                    Text(importMessage)
                        .font(.footnote.weight(.medium))
                        .padding(10)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                }
            }
        }
    }

    private func importBookmarks() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.html]
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.message = "Choose a bookmarks HTML export (Chrome, Firefox, Safari, Brave, Opera)"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url),
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        else {
            importMessage = "Could not read that file."
            return
        }
        let count = environment.bookmarks.importHTML(html)
        importMessage = count == 0 ? "No new bookmarks found." : "Imported \(count) bookmarks."
        #else
        if let html = UIPasteboard.general.string, html.lowercased().contains("<a") {
            let count = environment.bookmarks.importHTML(html)
            importMessage = count == 0 ? "No new bookmarks in clipboard." : "Imported \(count) from clipboard."
        } else {
            importMessage = "Copy a bookmarks HTML export, then tap Import again."
        }
        #endif
    }
}
