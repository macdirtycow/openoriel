import SwiftUI

struct BookmarksView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

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
                        description: Text("Bookmark the current page from the toolbar.")
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
            }
        }
    }
}
