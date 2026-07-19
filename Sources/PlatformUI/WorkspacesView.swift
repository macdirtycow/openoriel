import SwiftUI

struct WorkspacesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var renameText = ""
    @State private var renamingID: UUID?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(WorkspacePreset.allCases) { preset in
                        Button {
                            environment.applyWorkspacePreset(preset)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: preset.systemImage)
                                    .foregroundStyle(environment.settings.brandColor)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.displayName)
                                        .foregroundStyle(.primary)
                                    Text(preset.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Pulse presets")
                } footer: {
                    Text("Creates a workspace with starter tabs and Pulse performance defaults. Same privacy model as Classic Oriel.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    ForEach(environment.workspaces.workspaces) { workspace in
                        Button {
                            environment.switchWorkspace(id: workspace.id)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(workspace.name)
                                        .foregroundStyle(.primary)
                                    Text("\(workspace.snapshot.tabs.count) tabs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if workspace.id == environment.workspaces.activeWorkspaceID {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(environment.settings.brandColor)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("Rename") {
                                renamingID = workspace.id
                                renameText = workspace.name
                            }
                            .tint(.blue)
                            if environment.workspaces.workspaces.count > 1 {
                                Button("Delete", role: .destructive) {
                                    environment.workspaces.delete(id: workspace.id)
                                }
                            }
                        }
                        .contextMenu {
                            Button("Rename…") {
                                renamingID = workspace.id
                                renameText = workspace.name
                            }
                            if environment.workspaces.workspaces.count > 1 {
                                Button("Delete", role: .destructive) {
                                    environment.workspaces.delete(id: workspace.id)
                                }
                            }
                        }
                    }
                } footer: {
                    Text("Workspaces keep separate tab sets. Profiles isolate cookies; workspaces organize tabs.")
                }

                Section("New workspace") {
                    HStack {
                        TextField("Name", text: $newName)
                        Button("Add") {
                            let snapshot = environment.tabs.makeSessionSnapshot()
                            let created = environment.workspaces.create(name: newName, snapshot: snapshot)
                            newName = ""
                            environment.switchWorkspace(id: created.id)
                            dismiss()
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("Workspaces")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Rename Workspace", isPresented: Binding(
                get: { renamingID != nil },
                set: { if !$0 { renamingID = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renamingID = nil }
                Button("Save") {
                    if let id = renamingID {
                        environment.workspaces.rename(id: id, name: renameText)
                    }
                    renamingID = nil
                }
            }
        }
    }
}
