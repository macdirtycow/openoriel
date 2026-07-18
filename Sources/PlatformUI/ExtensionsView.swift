import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ExtensionsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var isInstalling = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Extensions")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                    #if os(macOS)
                    if environment.extensions.isSupported {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Task { await pickAndInstall() }
                            } label: {
                                if isInstalling {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Text("Install…")
                                }
                            }
                            .disabled(isInstalling)
                        }
                    }
                    #endif
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if environment.extensions.isSupported {
            supportedList
        } else {
            unsupportedBody
        }
    }

    private var supportedList: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Use Add to Oriel on the Chrome Web Store. Already installed extensions show as Installed and won’t duplicate.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Open an extension from the list or the puzzle menu in the toolbar.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                .listRowBackground(Color.clear)
            }

            if let status = environment.extensions.statusMessage {
                Section {
                    Label(status, systemImage: environment.extensions.isInstallingFromStore ? "arrow.down.circle" : "checkmark.circle")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    environment.openURLInNewTab(BrowserConstants.chromeWebStoreURL)
                    dismiss()
                } label: {
                    Label("Open Chrome Web Store", systemImage: "safari")
                }

                #if os(macOS)
                Button {
                    Task { await pickAndInstall() }
                } label: {
                    Label(isInstalling ? "Installing…" : "Install from file…", systemImage: "plus.square.on.square")
                }
                .disabled(isInstalling || environment.extensions.isInstallingFromStore)
                #endif
            } header: {
                Text("Get extensions")
            }

            Section {
                if environment.extensions.extensions.isEmpty {
                    HStack(spacing: 12) {
                        Image(systemName: "puzzlepiece.extension")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No extensions installed")
                                .font(.subheadline.weight(.semibold))
                            Text("Installed packages will appear here.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                } else {
                    ForEach(environment.extensions.extensions) { item in
                        extensionRow(item)
                    }
                }
            } header: {
                Text("Installed")
            }

            if let error = environment.extensions.lastError {
                Section("Status") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }

    private func extensionRow(_ item: InstalledExtensionInfo) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "puzzlepiece.extension.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(item.isEnabled ? "Version \(item.version)" : "Disabled · v\(item.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            #if os(macOS)
            Button {
                environment.extensions.openAction(for: item.id)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .help("Open extension")
            .disabled(!item.isEnabled)
            .accessibilityLabel("Open \(item.displayName)")
            #endif

            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { item.isEnabled },
                    set: { newValue in
                        Task { await environment.extensions.setEnabled(newValue, id: item.id) }
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel("\(item.displayName) enabled")

            Button(role: .destructive) {
                Task { await environment.extensions.remove(id: item.id) }
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Remove")
            .accessibilityLabel("Remove \(item.displayName)")
        }
        .padding(.vertical, 4)
    }

    private var unsupportedBody: some View {
        ContentUnavailableView {
            Label("Extensions unavailable", systemImage: "puzzlepiece.extension")
        } description: {
            Text(environment.extensions.lastError
                  ?? "Chrome-style extensions require macOS 15.4+. They are not available on this device yet.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if os(macOS)
    private func pickAndInstall() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .zip,
            UTType(filenameExtension: "crx") ?? .data,
            .folder
        ]
        panel.message = "Choose an unpacked extension folder, .zip, or .crx package"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        isInstalling = true
        defer { isInstalling = false }
        await environment.extensions.installFromPackage(at: url)
    }
    #endif
}
