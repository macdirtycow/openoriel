import SwiftUI

struct TabOverviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var newGroupName = ""
    @State private var showNewGroupAlert = false
    @State private var renameGroupID: UUID?
    @State private var renameGroupName = ""

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    private var filteredTabs: [BrowserTab] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let all = environment.tabs.tabs
        guard !q.isEmpty else { return all }
        return all.filter {
            $0.displayTitle.lowercased().contains(q)
                || $0.restorableURL.absoluteString.lowercased().contains(q)
                || ($0.restorableURL.host?.lowercased().contains(q) ?? false)
        }
    }

    private var ungroupedTabs: [BrowserTab] {
        filteredTabs.filter { $0.groupID == nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    ForEach(environment.tabs.groups) { group in
                        let tabs = filteredTabs.filter { $0.groupID == group.id }
                        if query.isEmpty || !tabs.isEmpty {
                            groupSection(group, tabs: tabs)
                        }
                    }

                    if !ungroupedTabs.isEmpty || environment.tabs.groups.isEmpty {
                        sectionHeader("Tabs", color: .secondary)
                        tabGrid(ungroupedTabs)
                    }
                }
                .padding()
            }
            .navigationTitle("Tabs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .searchable(text: $query, prompt: "Search tabs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        environment.tabs.createTab(select: true)
                        environment.wireTabPrivacyHooks()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Tab")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Private Tab") {
                            environment.tabs.createPrivateTab(select: true)
                            environment.wireTabPrivacyHooks()
                            dismiss()
                        }
                        Button("New Tab Group…") {
                            newGroupName = ""
                            showNewGroupAlert = true
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More tab actions")
                }
            }
            .alert("New Tab Group", isPresented: $showNewGroupAlert) {
                TextField("Group name", text: $newGroupName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    _ = environment.tabs.createGroup(name: newGroupName)
                }
            }
            .alert("Rename Group", isPresented: Binding(
                get: { renameGroupID != nil },
                set: { if !$0 { renameGroupID = nil } }
            )) {
                TextField("Group name", text: $renameGroupName)
                Button("Cancel", role: .cancel) { renameGroupID = nil }
                Button("Save") {
                    if let id = renameGroupID {
                        environment.tabs.renameGroup(id: id, name: renameGroupName)
                    }
                    renameGroupID = nil
                }
            }
        }
    }

    private func groupSection(_ group: TabGroup, tabs: [BrowserTab]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeader(group.name, color: group.color)
                Spacer()
                Menu {
                    Button("Add Current Tab") {
                        if let id = environment.tabs.activeTabID {
                            environment.tabs.assign(tabID: id, toGroup: group.id)
                        }
                    }
                    Button("Rename…") {
                        renameGroupID = group.id
                        renameGroupName = group.name
                    }
                    Button("Delete Group", role: .destructive) {
                        environment.tabs.deleteGroup(id: group.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
            }
            if tabs.isEmpty {
                Text("No tabs in this group")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                tabGrid(tabs)
            }
        }
    }

    private func sectionHeader(_ title: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
                .font(.headline)
        }
    }

    private func tabGrid(_ tabs: [BrowserTab]) -> some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(tabs) { tab in
                tabCard(tab)
            }
        }
    }

    private func tabCard(_ tab: BrowserTab) -> some View {
        let isActive = tab.id == environment.tabs.activeTabID
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                FaviconImage(pageURL: tab.restorableURL, size: 18)
                if tab.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityLabel("Pinned")
                }
                if tab.isPrivate {
                    Image(systemName: "eyeglasses")
                        .foregroundStyle(.purple)
                        .accessibilityLabel("Private")
                }
                Text(tab.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                Menu {
                    Button(tab.isPinned ? "Unpin" : "Pin") {
                        environment.tabs.togglePin(id: tab.id)
                    }
                    Menu("Move to Group") {
                        Button("Ungrouped") {
                            environment.tabs.assign(tabID: tab.id, toGroup: nil)
                        }
                        ForEach(environment.tabs.groups) { group in
                            Button(group.name) {
                                environment.tabs.assign(tabID: tab.id, toGroup: group.id)
                            }
                        }
                    }
                    Button("Close", role: .destructive) {
                        environment.tabs.closeTab(id: tab.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tab actions")
            }

            Text(tab.restorableURL.host ?? tab.restorableURL.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            tab.isPrivate ? Color.purple.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            environment.tabs.selectTab(id: tab.id)
            dismiss()
        }
    }
}
