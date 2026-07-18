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
                    Label {
                        Text("Profiles currently save a name only. Separate cookies and history per profile are not wired yet — switching does not isolate browsing data.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                }

                ForEach(environment.profiles.profiles) { profile in
                    Button {
                        environment.profiles.select(id: profile.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name)
                                if profile.isPrivateContainer {
                                    Text("Container")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
}
