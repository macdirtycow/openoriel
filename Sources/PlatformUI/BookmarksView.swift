import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct BookmarksView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var folderID: UUID?
    @State private var importMessage: String?
    @State private var newFolderName = ""
    @State private var showNewFolderAlert = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportFile = BookmarksHTMLFile(html: "")

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var results: [Bookmark] {
        if isSearching {
            return environment.bookmarks.search(query)
        }
        return environment.bookmarks.children(of: folderID)
    }

    private var folderTitle: String {
        if let folderID,
           let folder = environment.bookmarks.bookmarks.first(where: { $0.id == folderID }) {
            return folder.title
        }
        return "Bookmarks"
    }

    var body: some View {
        NavigationStack {
            Group {
                if results.isEmpty {
                    ContentUnavailableView(
                        isSearching ? "No Matches" : "No Bookmarks",
                        systemImage: "bookmark",
                        description: Text(
                            isSearching
                                ? "Try a different search."
                                : "Bookmark the current page, create a folder, or import an HTML export."
                        )
                    )
                } else {
                    List {
                        ForEach(results) { item in
                            bookmarkRow(item)
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                environment.bookmarks.remove(id: results[index].id)
                            }
                        }
                    }
                }
            }
            .navigationTitle(folderTitle)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $query, prompt: "Search bookmarks")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if folderID != nil, !isSearching {
                        Button("Back") {
                            if let current = folderID,
                               let parent = environment.bookmarks.bookmarks.first(where: { $0.id == current })?.parentID {
                                folderID = parent
                            } else {
                                folderID = nil
                            }
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Folder…") {
                            newFolderName = ""
                            showNewFolderAlert = true
                        }
                        Button("Import…") { importBookmarks() }
                        Button("Export…") { exportBookmarks() }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("New Folder", isPresented: $showNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    _ = environment.bookmarks.addFolder(title: newFolderName, parentID: folderID)
                }
            } message: {
                Text("Folders help organize bookmarks.")
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
            .fileExporter(
                isPresented: $showExporter,
                document: exportFile,
                contentType: .html,
                defaultFilename: "oriel-bookmarks"
            ) { result in
                switch result {
                case .success:
                    importMessage = "Exported bookmarks."
                case .failure:
                    importMessage = "Export failed."
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.html],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
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
                case .failure:
                    importMessage = "Import failed."
                }
            }
        }
    }

    @ViewBuilder
    private func bookmarkRow(_ item: Bookmark) -> some View {
        if item.isFolder {
            Button {
                folderID = item.id
                query = ""
            } label: {
                Label(item.title, systemImage: "folder.fill")
                    .foregroundStyle(.primary)
            }
            .swipeActions {
                Button(role: .destructive) {
                    environment.bookmarks.remove(id: item.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        } else {
            Button {
                if let url = item.url {
                    environment.tabs.activeTab?.load(url)
                    dismiss()
                }
            } label: {
                HStack(spacing: 10) {
                    FaviconImage(pageURL: item.url, size: 18)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .foregroundStyle(.primary)
                        Text(item.urlString ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if item.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                    }
                }
            }
            .contextMenu {
                Button(item.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                    environment.bookmarks.toggleFavorite(id: item.id)
                }
                Menu("Move to Folder") {
                    Button("Bookmarks Bar (Root)") {
                        environment.bookmarks.move(id: item.id, toParent: nil)
                    }
                    ForEach(environment.bookmarks.bookmarks.filter(\.isFolder)) { folder in
                        Button(folder.title) {
                            environment.bookmarks.move(id: item.id, toParent: folder.id)
                        }
                    }
                }
                Button("Delete", role: .destructive) {
                    environment.bookmarks.remove(id: item.id)
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
        showImporter = true
        #endif
    }

    private func exportBookmarks() {
        let html = environment.bookmarks.exportHTML()
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.html]
        panel.nameFieldStringValue = "oriel-bookmarks.html"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try html.data(using: .utf8)?.write(to: url, options: .atomic)
            importMessage = "Exported bookmarks."
        } catch {
            importMessage = "Export failed."
        }
        #else
        exportFile = BookmarksHTMLFile(html: html)
        showExporter = true
        #endif
    }
}

struct BookmarksHTMLFile: FileDocument {
    static var readableContentTypes: [UTType] { [.html] }
    var html: String

    init(html: String) {
        self.html = html
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents,
           let string = String(data: data, encoding: .utf8) {
            html = string
        } else {
            html = ""
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(html.utf8))
    }
}
