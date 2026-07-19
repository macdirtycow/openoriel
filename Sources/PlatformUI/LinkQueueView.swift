import SwiftUI

struct LinkQueueView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if environment.linkQueue.items.isEmpty {
                    ContentUnavailableView(
                        "Reading List is empty",
                        systemImage: "text.book.closed",
                        description: Text("Save pages with Add to Reading List, then open them here.")
                    )
                } else {
                    List {
                        ForEach(environment.linkQueue.items) { item in
                            HStack(spacing: 12) {
                                FaviconImage(pageURL: item.url, size: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 6) {
                                        if item.isUnread {
                                            Circle()
                                                .fill(environment.settings.brandColor)
                                                .frame(width: 7, height: 7)
                                        }
                                        Text(item.title)
                                            .font(.body.weight(item.isUnread ? .semibold : .medium))
                                            .lineLimit(1)
                                    }
                                    Text(item.urlString)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Button("Open") {
                                    open(item)
                                }
                                .buttonStyle(.bordered)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    environment.linkQueue.remove(id: item.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    environment.linkQueue.toggleReader(id: item.id)
                                } label: {
                                    Label(
                                        item.openInReader ? "Normal" : "Reader",
                                        systemImage: "doc.plaintext"
                                    )
                                }
                                .tint(environment.settings.brandColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reading List")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Open All") { openAll() }
                            .disabled(environment.linkQueue.items.isEmpty)
                        Button("Clear List", role: .destructive) {
                            environment.linkQueue.clear()
                        }
                        .disabled(environment.linkQueue.items.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
    }

    private func open(_ item: QueuedLink) {
        guard let url = item.url else { return }
        let preferReader = item.openInReader
        environment.linkQueue.markRead(id: item.id)
        environment.linkQueue.remove(id: item.id)
        environment.openURLInNewTab(url)
        if preferReader {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                environment.activeTab?.toggleReaderMode()
            }
        }
        dismiss()
    }

    private func openAll() {
        let batch = environment.linkQueue.consumeAll()
        for item in batch.reversed() {
            guard let url = item.url else { continue }
            environment.openURLInNewTab(url)
        }
        dismiss()
    }
}
