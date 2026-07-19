import SwiftUI

/// Oriel Password Vault — encrypted credentials (Classic + Pulse; Mac-first).
struct PasswordVaultView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton: Bool = true

    @State private var draftHost = ""
    @State private var draftUser = ""
    @State private var draftPassword = ""
    @State private var draftNotes = ""
    @State private var editingID: UUID?
    @State private var showEditor = false
    @State private var revealID: UUID?

    private var vault: PasswordVaultStore { environment.passwordVault }

    var body: some View {
        Group {
            if showsDoneButton {
                NavigationStack { formContent.toolbar { doneButton } }
            } else {
                formContent
            }
        }
    }

    @ToolbarContentBuilder
    private var doneButton: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
    }

    private var formContent: some View {
        Form {
            Section {
                Toggle("Enable Password Vault", isOn: Binding(
                    get: { vault.isEnabled },
                    set: { vault.setEnabled($0) }
                ))
                if vault.isEnabled {
                    if vault.isUnlocked {
                        Label("Unlocked", systemImage: "lock.open.fill")
                            .foregroundStyle(.secondary)
                        Button("Lock now", role: .destructive) { vault.lock() }
                    } else {
                        Button("Unlock Vault…") {
                            Task { _ = await vault.unlock() }
                        }
                    }
                }
                if let error = vault.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            } header: {
                Text("Vault")
            } footer: {
                Text("Passwords are AES-GCM encrypted on disk. The vault key stays in the system Keychain and unlock uses Touch ID / your Mac password. This is separate from iCloud Keychain autofill.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            if vault.isEnabled, vault.isUnlocked {
                Section {
                    Button {
                        editingID = nil
                        draftHost = environment.activeTab?.navigation.url?.host ?? ""
                        draftUser = ""
                        draftPassword = ""
                        draftNotes = ""
                        showEditor = true
                    } label: {
                        Label("Add password", systemImage: "plus")
                    }
                    if let host = environment.activeTab?.navigation.url?.host {
                        Button("Fill best match for \(host)") {
                            Task { await environment.autofillFromVaultForActivePage() }
                        }
                    }
                }

                Section {
                    if vault.credentials.isEmpty {
                        Text("No saved passwords yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(vault.credentials) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayHost)
                                    .font(.headline)
                                Text(item.username)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    Text(revealID == item.id ? item.password : String(repeating: "•", count: max(8, item.password.count)))
                                        .font(.caption.monospaced())
                                    Spacer()
                                    Button(revealID == item.id ? "Hide" : "Show") {
                                        revealID = revealID == item.id ? nil : item.id
                                    }
                                    .buttonStyle(.borderless)
                                    Button("Fill") {
                                        Task { await environment.fillVaultCredential(item) }
                                    }
                                    .buttonStyle(.borderless)
                                    Button("Edit") {
                                        editingID = item.id
                                        draftHost = item.host
                                        draftUser = item.username
                                        draftPassword = item.password
                                        draftNotes = item.notes
                                        showEditor = true
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .padding(.vertical, 2)
                            .contextMenu {
                                Button("Fill") {
                                    Task { await environment.fillVaultCredential(item) }
                                }
                                Button("Edit") {
                                    editingID = item.id
                                    draftHost = item.host
                                    draftUser = item.username
                                    draftPassword = item.password
                                    draftNotes = item.notes
                                    showEditor = true
                                }
                                Button("Delete", role: .destructive) {
                                    try? vault.delete(id: item.id)
                                }
                            }
                            #if os(iOS)
                            .swipeActions {
                                Button(role: .destructive) {
                                    try? vault.delete(id: item.id)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            #endif
                        }
                    }
                } header: {
                    Text("Saved (\(vault.credentials.count))")
                }
            }

            #if os(macOS)
            Section {
                Button("System Keychain autofill…") {
                    Task { await environment.autofillPasswordForActivePage() }
                }
            } footer: {
                Text("Still available: fill from iCloud Keychain via the system picker.")
            }
            #endif
        }
        .navigationTitle("Password Vault")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 480)
        #endif
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                Form {
                    TextField("Site host", text: $draftHost)
                    TextField("Username", text: $draftUser)
                    SecureField("Password", text: $draftPassword)
                    TextField("Notes", text: $draftNotes, axis: .vertical)
                        .lineLimit(3...6)
                }
                .navigationTitle(editingID == nil ? "Add password" : "Edit password")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { saveDraft() }
                            .disabled(draftHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                      || draftPassword.isEmpty)
                    }
                }
            }
            #if os(macOS)
            .frame(minWidth: 360, minHeight: 280)
            #endif
        }
    }

    private func saveDraft() {
        let item = VaultCredential(
            id: editingID ?? UUID(),
            host: draftHost,
            username: draftUser,
            password: draftPassword,
            notes: draftNotes
        )
        do {
            try vault.upsert(item)
            showEditor = false
            environment.flashStatus("Saved password for \(item.displayHost)")
        } catch {
            // Surface via vault.lastError on next unlock; also flash.
            environment.flashStatus(error.localizedDescription)
        }
    }
}
