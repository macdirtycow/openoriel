import SwiftUI

struct HistoryView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [HistoryEntry] {
        environment.history.search(query)
    }

    var body: some View {
        NavigationStack {
            Group {
                if filtered.isEmpty && environment.icloudSync.remoteSession?.tabs.isEmpty != false {
                    ContentUnavailableView(
                        "No History",
                        systemImage: "clock",
                        description: Text("Sites you visit will appear here.")
                    )
                } else if query.isEmpty {
                    List {
                        if let remote = environment.icloudSync.remoteSession, !remote.tabs.isEmpty {
                            Section {
                                ForEach(remote.tabs, id: \.id) { tab in
                                    Button {
                                        if let url = URL(string: tab.urlString) {
                                            environment.openURLInNewTab(url)
                                            dismiss()
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(tab.title)
                                                .foregroundStyle(.primary)
                                            Text(tab.urlString)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                Button("Replace local tabs with remote session") {
                                    environment.applyRemoteSession(remote)
                                    dismiss()
                                }
                                .foregroundStyle(.orange)
                            } header: {
                                Text("Tabs from other devices")
                            }
                        }
                        ForEach(environment.history.groupedByDay, id: \.day) { group in
                            Section(header: Text(sectionTitle(for: group.day))) {
                                ForEach(group.entries) { entry in
                                    historyRow(entry)
                                }
                            }
                        }
                    }
                } else if filtered.isEmpty {
                    ContentUnavailableView(
                        "No Matches",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different search.")
                    )
                } else {
                    List(filtered) { entry in
                        historyRow(entry)
                    }
                }
            }
            .navigationTitle("History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $query, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu("Clear") {
                        Button("Clear Last Hour") { environment.history.clearLastHour() }
                        Button("Clear Last Day") { environment.history.clearLastDay() }
                        Button("Clear All", role: .destructive) { environment.history.clear() }
                    }
                }
            }
        }
    }

    private func historyRow(_ entry: HistoryEntry) -> some View {
        Button {
            if let url = entry.url {
                environment.tabs.activeTab?.load(url)
                dismiss()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.title)
                    .foregroundStyle(.primary)
                Text(entry.urlString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func sectionTitle(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}
