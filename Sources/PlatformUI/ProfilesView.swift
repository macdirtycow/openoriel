import SwiftUI

struct ProfilesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Each profile has its own cookies and site data. Private tabs always use a temporary jar.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(environment.profiles.profiles) { profile in
                    Button {
                        environment.profiles.select(id: profile.id)
                        // Remount web views onto the selected cookie jar.
                        for tab in environment.tabs.tabs where !tab.isPrivate {
                            tab.webView = nil
                        }
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                Text(profileSubtitle(profile))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if profile.id == environment.profiles.activeProfileID {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(environment.settings.brandColor)
                            }
                        }
                    }
                    .swipeActions {
                        if environment.profiles.profiles.count > 1 {
                            Button(role: .destructive) {
                                environment.profiles.delete(id: profile.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Profiles")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Add") {
                        newName = ""
                        showNew = true
                    }
                }
            }
            .alert("New Profile", isPresented: $showNew) {
                TextField("Name", text: $newName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    _ = environment.profiles.create(name: newName)
                }
            }
        }
    }

    private func profileSubtitle(_ profile: BrowserProfile) -> String {
        if profile.isPrivateContainer {
            return "Temporary container"
        }
        if profile.usesSharedDefaultStore {
            return "Default cookie store"
        }
        return "Isolated cookie store"
    }
}
