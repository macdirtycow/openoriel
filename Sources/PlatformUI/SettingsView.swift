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

                Section {
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

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent color")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                            ForEach(BrowserAccentTheme.allCases) { theme in
                                Button {
                                    settings.accentTheme = theme
                                } label: {
                                    VStack(spacing: 6) {
                                        Circle()
                                            .fill(theme.color)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                            }
                                            .overlay {
                                                if settings.accentTheme == theme {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption.weight(.bold))
                                                        .foregroundStyle(.white)
                                                }
                                            }
                                        Text(theme.displayName)
                                            .font(.caption2.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(
                                        settings.accentTheme == theme
                                            ? theme.color.opacity(0.12)
                                            : Color.primary.opacity(0.03),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(
                                                settings.accentTheme == theme
                                                    ? theme.color.opacity(0.45)
                                                    : Color.primary.opacity(0.08),
                                                lineWidth: 1
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(settings.accentTheme == theme ? [.isSelected] : [])
                                .accessibilityLabel("\(theme.displayName) accent")
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Background")
                            .font(.subheadline.weight(.semibold))
                        ForEach(BrowserBackgroundTheme.allCases) { theme in
                            Button {
                                settings.backgroundTheme = theme
                                if let forced = theme.forcedColorScheme {
                                    settings.appearance = forced == .dark ? .dark : .light
                                }
                            } label: {
                                HStack(spacing: 12) {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(backgroundPreview(theme))
                                        .frame(width: 44, height: 28)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                                        }
                                    Text(theme.displayName)
                                        .foregroundStyle(.primary)
                                    Spacer(minLength: 0)
                                    if settings.backgroundTheme == theme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(settings.brandColor)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(settings.backgroundTheme == theme ? [.isSelected] : [])
                        }
                    }
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("Accent colors tint buttons and Shields. Backgrounds like Midnight or Paper also set Light/Dark so text stays readable.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Toggle("Enable JavaScript by default", isOn: $settings.javaScriptEnabledByDefault)
                    Toggle("Block media autoplay", isOn: $settings.blockAutoplay)
                } header: {
                    Text("Page media")
                } footer: {
                    Text("New tabs use the JavaScript default. Autoplay blocking applies to newly created tab WebViews — reopen a tab after changing it. Use the JS button to toggle the current tab.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    Toggle("Strip tracking parameters from URLs", isOn: $settings.stripTrackingParameters)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Removes common trackers like utm_*, fbclid, and gclid from links you open. Focus Mode (⋯ menu) also mutes media and hides cookie banners on the current tab.")
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
                    Text("On chromewebstore.google.com, click Add to Oriel to install. You can also load a .zip / .crx / folder manually.")
                        .fixedSize(horizontal: false, vertical: true)
                    #else
                    Text("Full Chrome-style extensions are not available on iPhone and iPad.")
                        .fixedSize(horizontal: false, vertical: true)
                    #endif
                }

                Section {
                    Link(destination: BrowserConstants.donateURL) {
                        Label("Donate via PayPal", systemImage: "heart.fill")
                    }
                    Link(destination: BrowserConstants.supportURL) {
                        Label("Support & website", systemImage: "questionmark.circle")
                    }
                    Link(destination: BrowserConstants.privacyPolicyURL) {
                        Label("Privacy policy", systemImage: "hand.raised")
                    }
                } header: {
                    Text("Support")
                } footer: {
                    Text("Donations go to paypal.me/macdirtycow and help fund Oriel development.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("About") {
                    LabeledContent("Product", value: BrowserConstants.productName)
                    LabeledContent("Version", value: appVersionLabel)
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

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }

    private func backgroundPreview(_ theme: BrowserBackgroundTheme) -> some ShapeStyle {
        switch theme {
        case .soft: Color(red: 0.94, green: 0.93, blue: 0.91)
        case .paper: Color(red: 0.98, green: 0.96, blue: 0.93)
        case .mist: Color(red: 0.90, green: 0.93, blue: 0.96)
        case .sand: Color(red: 0.94, green: 0.89, blue: 0.80)
        case .aurora: Color(red: 0.82, green: 0.88, blue: 0.96)
        case .midnight: Color(red: 0.12, green: 0.14, blue: 0.18)
        }
    }
}
