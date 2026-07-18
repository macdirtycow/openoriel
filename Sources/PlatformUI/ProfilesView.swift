import SwiftUI

struct ProfilesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @State private var showNew = false
    @State private var renameTarget: BrowserProfile?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    activeProfileHeader
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                .listRowBackground(Color.clear)

                Section {
                    Text("Each profile has its own cookies and site data. Switching remounts open tabs onto that jar. Private tabs always use a temporary store.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Your profiles") {
                    ForEach(environment.profiles.profiles) { profile in
                        profileRow(profile)
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
                    Button {
                        newName = ""
                        showNew = true
                    } label: {
                        Label("Add Profile", systemImage: "plus")
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
            } message: {
                Text("Give this profile a name. Cookies and logins stay separate from your other profiles.")
            }
            .alert(
                "Rename Profile",
                isPresented: Binding(
                    get: { renameTarget != nil },
                    set: { if !$0 { renameTarget = nil } }
                )
            ) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renameTarget = nil }
                Button("Save") {
                    if let target = renameTarget {
                        environment.profiles.rename(id: target.id, name: renameText)
                    }
                    renameTarget = nil
                }
            }
        }
    }

    private var activeProfileHeader: some View {
        let active = environment.profiles.activeProfile
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(environment.settings.brandColor.opacity(0.18))
                        .frame(width: 56, height: 56)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(environment.settings.brandColor)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Active profile")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(active.name)
                        .font(.title2.weight(.semibold))
                    Text(profileSubtitle(active))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            Text("\(environment.profiles.profiles.count) profile\(environment.profiles.profiles.count == 1 ? "" : "s") on this device")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func profileRow(_ profile: BrowserProfile) -> some View {
        let isActive = profile.id == environment.profiles.activeProfileID
        return HStack(alignment: .center, spacing: 12) {
            Button {
                environment.applyProfile(id: profile.id)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "person.crop.circle")
                        .font(.title3)
                        .foregroundStyle(isActive ? environment.settings.brandColor : .secondary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.name)
                            .font(.body.weight(isActive ? .semibold : .regular))
                            .foregroundStyle(.primary)
                        Text(profileSubtitle(profile))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button("Switch to This Profile") {
                    environment.applyProfile(id: profile.id)
                    dismiss()
                }
                Button("Rename…") {
                    renameTarget = profile
                    renameText = profile.name
                }
                if profile.usesSharedDefaultStore {
                    Button("Convert to Isolated Cookie Store") {
                        environment.profiles.convertToIsolatedStore(id: profile.id)
                        if profile.id == environment.profiles.activeProfileID {
                            environment.applyProfile(id: profile.id)
                        }
                    }
                }
                if environment.profiles.profiles.count > 1 {
                    Divider()
                    Button("Delete", role: .destructive) {
                        environment.profiles.delete(id: profile.id)
                        environment.applyProfile(id: environment.profiles.activeProfileID)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
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
