import SwiftUI

/// Recently closed tabs list (cap comes from `TabManager`).
struct RecentlyClosedView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if environment.tabs.closedTabs.isEmpty {
                    ContentUnavailableView(
                        "No recently closed tabs",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Closed tabs appear here so you can restore them.")
                    )
                } else {
                    List {
                        ForEach(Array(environment.tabs.closedTabs.enumerated()), id: \.offset) { index, record in
                            Button {
                                _ = environment.tabs.restoreClosedTab(at: index)
                                environment.wireTabPrivacyHooks()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    FaviconImage(pageURL: record.url, size: 18)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(record.title)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                        Text(record.url.absoluteString)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.uturn.backward")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Recently Closed")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Clear", role: .destructive) {
                        environment.tabs.clearClosedTabs()
                    }
                    .disabled(environment.tabs.closedTabs.isEmpty)
                }
            }
        }
    }
}
