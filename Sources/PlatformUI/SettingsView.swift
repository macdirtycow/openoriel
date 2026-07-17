import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                                        Text("Web search via Google")
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
                    Text("Used when you type words in the address bar instead of a website address. Current: \(settings.searchEngine.displayName).")
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
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("Appearance")
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

                Section("About") {
                    LabeledContent("Product", value: BrowserConstants.productName)
                    LabeledContent("Website", value: BrowserConstants.productWebsiteHost)
                    LabeledContent("Publisher", value: BrowserConstants.publisherName)
                    Link("Open \(BrowserConstants.productWebsiteHost)", destination: BrowserConstants.productWebsiteURL)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents(horizontalSizeClass == .compact ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }
}
