import SwiftUI

struct LinkQueueView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if environment.linkQueue.items.isEmpty {
                    ContentUnavailableView(
                        "Queue is empty",
                        systemImage: "tray",
                        description: Text("Use Open Later on a link to save it here.")
                    )
                } else {
                    List {
                        ForEach(environment.linkQueue.items) { item in
                            HStack(spacing: 12) {
                                FaviconImage(pageURL: item.url, size: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.title)
                                        .font(.body.weight(.medium))
                                        .lineLimit(1)
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
                            .swipeActions {
                                Button(role: .destructive) {
                                    environment.linkQueue.remove(id: item.id)
                                } label: {
                                    Label("Remove", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Open Later")
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
                        Button("Clear Queue", role: .destructive) {
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
        environment.linkQueue.remove(id: item.id)
        environment.openURLInNewTab(url)
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
