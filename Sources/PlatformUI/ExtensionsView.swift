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
    @State private var installingSafariID: String?

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
                        UTType(filenameExtension: "appex") ?? .data,
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
                VStack(alignment: .leading, spacing: 10) {
                    Text("Oriel runs Chrome/Firefox-style WebExtensions via Apple’s WKWebExtension API on macOS 15.4+ and iOS/iPadOS 18.4+.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Safari Web Extensions (the modern ones with manifest.json inside an .appex) can be imported. Legacy native Safari App Extensions still cannot leave Safari.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    #if os(iOS)
                    Text("On iPhone and iPad, pick a Safari Web Extension .appex or a folder that contains manifest.json. Extension action popups open as sheets when provided.")
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
                    Label("Open Chrome Web Store", systemImage: "bag")
                }

                Button {
                    #if os(macOS)
                    Task { await pickAndInstallMac() }
                    #else
                    showImporter = true
                    #endif
                } label: {
                    Label(isInstalling ? "Installing…" : "Install from file or folder…", systemImage: "plus.square.on.square")
                }
                .disabled(isInstalling || environment.extensions.isInstallingFromStore)
            } header: {
                Text("Get extensions")
            } footer: {
                Text("Chrome Web Store, .zip / .crx, unpacked folders, or Safari Web Extension .appex / project folders that include manifest.json.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            #if os(macOS)
            safariSection
            #endif

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

    #if os(macOS)
    private var safariSection: some View {
        Section {
            Button {
                environment.extensions.refreshSafariCandidates()
            } label: {
                if environment.extensions.isScanningSafari {
                    Label("Scanning Applications…", systemImage: "magnifyingglass")
                } else {
                    Label("Scan Applications for Safari extensions", systemImage: "safari")
                }
            }
            .disabled(environment.extensions.isScanningSafari || isInstalling)

            if environment.extensions.safariCandidates.isEmpty {
                Text("Install a Safari Web Extension app first (for example from the Mac App Store), then scan. Oriel looks under /Applications and ~/Applications for .appex packages.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(environment.extensions.safariCandidates) { candidate in
                    safariCandidateRow(candidate)
                }
            }
        } header: {
            Text("Safari")
        } footer: {
            Text("Imports peel the WebExtension resources out of a Safari .appex. Native-only Safari App Extensions and content blockers stay in Safari.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func safariCandidateRow(_ candidate: SafariExtensionCandidate) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: candidate.isImportable ? "puzzlepiece.extension.fill" : "lock.fill")
                .font(.title3)
                .foregroundStyle(candidate.isImportable ? environment.settings.brandColor : .secondary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.displayName)
                    .font(.body.weight(.semibold))
                    .lineLimit(1)
                Text(safariSubtitle(candidate))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if candidate.isImportable {
                Button {
                    Task {
                        installingSafariID = candidate.id
                        defer { installingSafariID = nil }
                        await environment.extensions.installSafariCandidate(candidate)
                    }
                } label: {
                    if installingSafariID == candidate.id {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Text("Import")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isInstalling || installingSafariID != nil || environment.extensions.isInstallingFromStore)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(candidate.displayName). \(candidate.statusDetail)")
    }

    private func safariSubtitle(_ candidate: SafariExtensionCandidate) -> String {
        var parts: [String] = ["v\(candidate.version)"]
        if let app = candidate.containingAppName {
            parts.append(app)
        }
        parts.append(candidate.statusDetail)
        return parts.joined(separator: " · ")
    }
    #endif

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
            UTType(filenameExtension: "appex") ?? .data,
            .folder
        ]
        panel.message = "Choose a WebExtension folder, .zip, .crx, Safari Web Extension .appex, or any package that contains manifest.json."
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
