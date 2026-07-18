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
                    Text("Each profile has its own cookies and site data. Switching remounts tabs onto that jar. Private tabs always use a temporary store.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ForEach(environment.profiles.profiles) { profile in
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            environment.applyProfile(id: profile.id)
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

                        if profile.usesSharedDefaultStore {
                            Button("Convert to isolated cookie store") {
                                environment.profiles.convertToIsolatedStore(id: profile.id)
                                if profile.id == environment.profiles.activeProfileID {
                                    environment.applyProfile(id: profile.id)
                                }
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .swipeActions {
                        if environment.profiles.profiles.count > 1 {
                            Button(role: .destructive) {
                                environment.profiles.delete(id: profile.id)
                                environment.applyProfile(id: environment.profiles.activeProfileID)
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
                    let profile = environment.profiles.create(name: newName)
                    environment.applyProfile(id: profile.id)
                }
            }
        }
    }

    private func profileSubtitle(_ profile: BrowserProfile) -> String {
        if profile.isPrivateContainer {
            return "Temporary container"
        }
        if profile.usesSharedDefaultStore {
            return "Shared default store (legacy)"
        }
        return "Isolated cookie store"
    }
}
