import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// When true, show a Done button (sheet). Native macOS Settings window can omit it.
    var showsDoneButton: Bool = true

    var body: some View {
        @Bindable var settings = environment.settings
        NavigationStack {
            Form {
                Section {
                    ForEach(SearchEngine.allCases) { engine in
                        Button {
                            environment.setSearchEngine(engine)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: engine.systemImage)
                                    .frame(width: 28)
                                    .foregroundStyle(Color.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(engine.displayName)
                                        .foregroundStyle(.primary)
                                    if engine == .google {
                                        Text("Web search + Google Account sign-in")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    } else if engine == .duckDuckGo {
                                        Text("Privacy-focused search")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if settings.searchEngine == engine {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.accentColor)
                                        .accessibilityLabel("Selected")
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(settings.searchEngine == engine ? [.isSelected] : [])
                    }
                } header: {
                    Text("Search engine")
                } footer: {
                    Text("Oriel does not host its own search index. Queries open \(settings.searchEngine.displayName)'s results page.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Tabs") {
                    Toggle("Restore previous session", isOn: $settings.restorePreviousSession)
                }

                Section("Appearance") {
                    Picker("Appearance", selection: $settings.appearance) {
                        ForEach(AppAppearance.allCases) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    #if os(macOS)
                    .pickerStyle(.radioGroup)
                    #else
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    #endif
                    .accessibilityLabel("Appearance")
                }

                Section {
                    Toggle("Enable JavaScript by default", isOn: $settings.javaScriptEnabledByDefault)
                } header: {
                    Text("JavaScript")
                } footer: {
                    Text("New tabs use this default. Use the JS button in the toolbar to toggle the current tab.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Homepage") {
                    Picker("New tab opens", selection: $settings.newTabBehavior) {
                        ForEach(NewTabBehavior.allCases) { behavior in
                            Text(behavior.displayName).tag(behavior)
                        }
                    }
                    if settings.newTabBehavior == .homepage {
                        TextField("Homepage URL", text: $settings.homepageURLString)
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            #endif
                    }
                }

                Section {
                    Button {
                        environment.showExtensions = true
                        if showsDoneButton {
                            dismiss()
                        }
                    } label: {
                        Label("Extensions…", systemImage: "puzzlepiece.extension")
                    }
                    #if os(macOS)
                    Button {
                        environment.openURLInNewTab(BrowserConstants.chromeWebStoreURL)
                        if showsDoneButton {
                            dismiss()
                        }
                    } label: {
                        Label("Browse Chrome Web Store", systemImage: "safari")
                    }
                    #endif
                } header: {
                    Text("Extensions")
                } footer: {
                    #if os(macOS)
                    Text("Install .zip / .crx / unpacked Manifest V2–V3 extensions. Chrome Web Store one-click install is not available; download a package, then install it in Oriel.")
                        .fixedSize(horizontal: false, vertical: true)
                    #else
                    Text("Full Chrome-style extensions are not available on iPhone and iPad.")
                        .fixedSize(horizontal: false, vertical: true)
                    #endif
                }

                Section("About") {
                    LabeledContent("Product", value: BrowserConstants.productName)
                    LabeledContent("Website", value: BrowserConstants.productWebsiteHost)
                    LabeledContent("Publisher", value: BrowserConstants.publisherName)
                    Link("Open \(BrowserConstants.productWebsiteHost)", destination: BrowserConstants.productWebsiteURL)
                }
            }
            .navigationTitle("Settings")
            #if os(macOS)
            .formStyle(.grouped)
            #else
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            .presentationDetents(horizontalSizeClass == .compact ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
    }
}
