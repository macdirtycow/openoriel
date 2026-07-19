import SwiftUI

/// Reader Hub — Reading List with Reader-first open, unread queue, and one-tap continue.
struct LinkQueueView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private var unread: [QueuedLink] {
        environment.linkQueue.items.filter(\.isUnread)
    }

    private var read: [QueuedLink] {
        environment.linkQueue.items.filter { !$0.isUnread }
    }

    var body: some View {
        NavigationStack {
            Group {
                if environment.linkQueue.items.isEmpty {
                    ContentUnavailableView(
                        "Reader Hub is empty",
                        systemImage: "text.book.closed",
                        description: Text("Save pages with Add to Reading List, then open them here in Reader Mode.")
                    )
                } else {
                    List {
                        if !unread.isEmpty {
                            Section("Unread · \(unread.count)") {
                                ForEach(unread) { item in
                                    row(item)
                                }
                            }
                        }
                        if !read.isEmpty {
                            Section("Saved") {
                                ForEach(read) { item in
                                    row(item)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reader Hub")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Open next unread in Reader") {
                            openNextUnread()
                        }
                        .disabled(unread.isEmpty)
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
            .safeAreaInset(edge: .bottom) {
                if let next = unread.first {
                    Button {
                        open(next, forceReader: true)
                    } label: {
                        Label("Continue in Reader", systemImage: "doc.plaintext.fill")
                            .font(.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(environment.settings.brandColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ item: QueuedLink) -> some View {
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
                    if item.openInReader {
                        Image(systemName: "doc.plaintext")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(item.urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Reader") {
                open(item, forceReader: true)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
                    item.openInReader ? "Normal" : "Prefer Reader",
                    systemImage: "doc.plaintext"
                )
            }
            .tint(environment.settings.brandColor)
            Button {
                open(item, forceReader: false)
            } label: {
                Label("Open", systemImage: "safari")
            }
        }
    }

    private func open(_ item: QueuedLink, forceReader: Bool) {
        guard let url = item.url else { return }
        let preferReader = forceReader || item.openInReader
        environment.linkQueue.markRead(id: item.id)
        environment.linkQueue.remove(id: item.id)
        environment.openURLInNewTab(url)
        if preferReader {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                environment.activeTab?.toggleReaderMode()
            }
        }
        dismiss()
    }

    private func openNextUnread() {
        guard let next = unread.first else { return }
        open(next, forceReader: true)
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
