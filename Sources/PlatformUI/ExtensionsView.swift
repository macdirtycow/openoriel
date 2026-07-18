import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct ExtensionsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var isInstalling = false
    @State private var showImporter = false

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
                    if environment.extensions.isSupported {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                #if os(macOS)
                                Task { await pickAndInstallMac() }
                                #else
                                showImporter = true
                                #endif
                            } label: {
                                if isInstalling {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    Image(systemName: "plus")
                                }
                            }
                            .disabled(isInstalling)
                            .accessibilityLabel("Install extension")
                        }
                    }
                }
                .fileImporter(
                    isPresented: $showImporter,
                    allowedContentTypes: [
                        .zip,
                        UTType(filenameExtension: "crx") ?? .data,
                        .folder
                    ],
                    allowsMultipleSelection: false
                ) { result in
                    guard case .success(let urls) = result, let url = urls.first else { return }
                    Task { await install(from: url) }
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
                    Text("Install from the Chrome Web Store or a .zip / .crx package. Content scripts and background pages run in Oriel tabs.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    #if os(iOS)
                    Text("Requires iOS 18.4+. Extension popups are limited on iPhone/iPad; most extensions still work via content scripts.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                    #endif
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

                Button {
                    #if os(macOS)
                    Task { await pickAndInstallMac() }
                    #else
                    showImporter = true
                    #endif
                } label: {
                    Label(isInstalling ? "Installing…" : "Install from file…", systemImage: "plus.square.on.square")
                }
                .disabled(isInstalling || environment.extensions.isInstallingFromStore)
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
                .foregroundStyle(environment.settings.brandColor)
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

            Button {
                environment.extensions.openAction(for: item.id)
            } label: {
                Image(systemName: "arrow.up.forward.app")
            }
            .buttonStyle(.borderless)
            .disabled(!item.isEnabled)
            .accessibilityLabel("Open \(item.displayName)")

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
            .accessibilityLabel("Remove \(item.displayName)")
        }
        .padding(.vertical, 4)
    }

    private var unsupportedBody: some View {
        ContentUnavailableView {
            Label("Extensions unavailable", systemImage: "puzzlepiece.extension")
        } description: {
            Text(environment.extensions.lastError
                  ?? "Chrome-style extensions require macOS 15.4+ or iOS 18.4+.")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    #if os(macOS)
    private func pickAndInstallMac() async {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [
            .zip,
            UTType(filenameExtension: "crx") ?? .data,
            .folder
        ]
        panel.prompt = "Install"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        await install(from: url)
    }
    #endif

    private func install(from url: URL) async {
        isInstalling = true
        defer { isInstalling = false }
        await environment.extensions.installFromPackage(at: url)
    }
}
