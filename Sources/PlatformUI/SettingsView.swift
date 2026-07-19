import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// When true, show a Done button (sheet). Native macOS Settings window can omit it.
    var showsDoneButton: Bool = true
    @State private var showProfilesSheet = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        SearchEngineSettingsPage()
                    } label: {
                        settingsRow(
                            "Search",
                            systemImage: "magnifyingglass",
                            detail: environment.settings.searchEngine.displayName
                        )
                    }

                    NavigationLink {
                        AppearanceSettingsPage()
                    } label: {
                        settingsRow(
                            "Appearance",
                            systemImage: "paintbrush.fill",
                            detail: appearanceDetail
                        )
                    }

                    NavigationLink {
                        PrivacySettingsPage()
                    } label: {
                        settingsRow("Privacy & media", systemImage: "hand.raised.fill")
                    }

                    NavigationLink {
                        DataInventoryView()
                    } label: {
                        settingsRow("What Oriel stores", systemImage: "internaldrive")
                    }
                }

                Section {
                    profileSummaryRow

                    NavigationLink {
                        AccountsSettingsPage(showsDoneButton: showsDoneButton)
                    } label: {
                        settingsRow("Accounts & sync", systemImage: "icloud.fill")
                    }

                    NavigationLink {
                        HomepageSettingsPage()
                    } label: {
                        settingsRow(
                            "Homepage",
                            systemImage: "house.fill",
                            detail: environment.settings.newTabBehavior.displayName
                        )
                    }

                    NavigationLink {
                        DefaultBrowserSettingsPage()
                    } label: {
                        settingsRow("Default browser", systemImage: "safari.fill")
                    }
                } header: {
                    Text("Browser")
                }

                Section {
                    Button {
                        environment.showExtensions = true
                        if showsDoneButton { dismiss() }
                    } label: {
                        settingsRow("Extensions", systemImage: "puzzlepiece.extension.fill")
                    }

                    if environment.extensions.isSupported {
                        Button {
                            environment.showOrielStore = true
                            if showsDoneButton { dismiss() }
                        } label: {
                            settingsRow("Oriel Store", systemImage: "storefront.fill")
                        }
                    }
                } header: {
                    Text("Add-ons")
                } footer: {
                    Text("Browse extensions and themes in Oriel Store. Manage installed ones under Extensions.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    NavigationLink {
                        AboutSettingsPage(showsDoneButton: showsDoneButton)
                    } label: {
                        settingsRow(
                            "About Oriel",
                            systemImage: "info.circle.fill",
                            detail: appVersionLabel
                        )
                    }
                }
            }
            .navigationTitle("Settings")
            #if os(macOS)
            .formStyle(.grouped)
            #else
            .navigationBarTitleDisplayMode(.inline)
            .listStyle(.insetGrouped)
            // Hub is short — large detent avoids a cramped half-sheet of endless scrolling.
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            #endif
            .toolbar {
                if showsDoneButton {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
            .sheet(isPresented: $showProfilesSheet) {
                ProfilesView()
                    .environment(environment)
                    .orielTheming(settings: environment.settings)
                    #if os(macOS)
                    .frame(minWidth: 420, idealWidth: 480, minHeight: 360, idealHeight: 480)
                    #endif
            }
        }
    }

    private var appearanceDetail: String {
        if environment.settings.usesExtensionTheme {
            return "Extension theme"
        }
        if environment.settings.edition.isPulse {
            return "Pulse"
        }
        return environment.settings.appearance.displayName
    }

    private var profileSummaryRow: some View {
        Button {
            if showsDoneButton {
                environment.showProfiles = true
                dismiss()
            } else {
                showProfilesSheet = true
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(environment.settings.brandColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(environment.profiles.activeProfile.name)
                        .foregroundStyle(.primary)
                    Text("Active profile")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsRow(_ title: String, systemImage: String, detail: String? = nil) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 28)
                .foregroundStyle(environment.settings.brandColor)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}

// MARK: - Search

private struct SearchEngineSettingsPage: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
            Section {
                ForEach(SearchEngine.allCases) { engine in
                    Button {
                        environment.setSearchEngine(engine)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: engine.systemImage)
                                .frame(width: 28)
                                .foregroundStyle(settings.brandColor)
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
                                    .foregroundStyle(settings.brandColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("Queries open \(settings.searchEngine.displayName)’s results page.")
            }

            Section {
                Toggle("Restore previous session", isOn: $settings.restorePreviousSession)
            } header: {
                Text("Tabs")
            }
        }
        .navigationTitle("Search")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

// MARK: - Appearance (themes + accents)

private struct AppearanceSettingsPage: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
            Section {
                ForEach(BrowserEdition.allCases) { edition in
                    Button {
                        environment.extensionThemes.clearActive()
                        environment.selectBrowserEdition(edition, applySuggestedLook: true)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: edition.systemImage)
                                .font(.title3)
                                .foregroundStyle(edition.isPulse ? EditionBranding.pulseAccent : settings.brandColor)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(edition.displayName)
                                    .foregroundStyle(.primary)
                                Text(edition.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Spacer(minLength: 0)
                            if settings.edition == edition {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(settings.brandColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Browser edition")
            } footer: {
                Text("Pulse is a look and performance mode inside Oriel — same privacy model, no separate Opera-style account.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Classic + Pulse — dual-engine preference is not Pulse-gated.
            PageEngineSettingsSection()

            if settings.edition.isPulse {
                Section {
                    NavigationLink {
                        PulsePerformanceView(showsDoneButton: false)
                    } label: {
                        Label("Pulse performance", systemImage: "bolt.horizontal")
                    }
                    Picker("Wallpaper", selection: $settings.pulseWallpaperID) {
                        ForEach(PulseWallpaper.allCases) { paper in
                            Text(paper.displayName).tag(paper.rawValue)
                        }
                    }
                    .onChange(of: settings.pulseWallpaperID) { _, _ in
                        environment.icloudSync.noteLocalChange()
                    }
                } footer: {
                    Text("Live page-engine limits, Data/Network Saver, Lucid Mode, and ambience.")
                }
            }

            Section {
                Picker("Mode", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                #if os(macOS)
                .pickerStyle(.radioGroup)
                #else
                .pickerStyle(.segmented)
                #endif
                .onChange(of: settings.appearance) { _, _ in
                    environment.icloudSync.noteLocalChange()
                }
            } header: {
                Text("Light & dark")
            } footer: {
                if settings.usesExtensionTheme {
                    Text("An extension theme is active and may override light/dark until you deactivate it.")
                }
            }

            if !environment.extensionThemes.themes.isEmpty {
                Section {
                    Button {
                        environment.extensionThemes.clearActive()
                        environment.icloudSync.noteLocalChange()
                    } label: {
                        HStack {
                            Label("Oriel default", systemImage: "circle.lefthalf.filled")
                            Spacer()
                            if !settings.usesExtensionTheme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(settings.brandColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)

                    ForEach(environment.extensionThemes.themes) { theme in
                        extensionThemeRow(theme)
                    }
                } header: {
                    Text("Installed themes")
                } footer: {
                    Text("Deactivate returns Oriel’s built-in look. The theme stays installed so you can turn it back on later.")
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Section {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                    ForEach(BrowserAccentTheme.allCases) { theme in
                        Button {
                            environment.extensionThemes.clearActive()
                            settings.accentTheme = theme
                            environment.icloudSync.noteLocalChange()
                        } label: {
                            VStack(spacing: 6) {
                                Circle()
                                    .fill(theme.color)
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Circle().strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                                    }
                                    .overlay {
                                        if settings.accentTheme == theme, !settings.usesExtensionTheme {
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
                                settings.accentTheme == theme && !settings.usesExtensionTheme
                                    ? theme.color.opacity(0.12)
                                    : Color.primary.opacity(0.03),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(settings.usesExtensionTheme)
                    }
                }
                .opacity(settings.usesExtensionTheme ? 0.45 : 1)
            } header: {
                Text("Accent color")
            } footer: {
                Text(settings.usesExtensionTheme
                    ? "Deactivate the extension theme to change accent colors."
                    : "Tints buttons and Shields.")
            }

            Section {
                ForEach(BrowserBackgroundTheme.allCases) { theme in
                    Button {
                        environment.extensionThemes.clearActive()
                        settings.backgroundTheme = theme
                        if let forced = theme.forcedColorScheme {
                            settings.appearance = forced == .dark ? .dark : .light
                        } else {
                            settings.appearance = .system
                        }
                        environment.icloudSync.noteLocalChange()
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
                            if settings.backgroundTheme == theme, !settings.usesExtensionTheme {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(settings.brandColor)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(settings.usesExtensionTheme)
                }
            } header: {
                Text("Background")
            } footer: {
                Text(settings.usesExtensionTheme
                    ? "Deactivate the extension theme to use Oriel backgrounds."
                    : "Soft, Paper, and Sand stay light; Midnight stays dark. Mist and Aurora follow System.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Appearance")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private func extensionThemeRow(_ theme: InstalledExtensionTheme) -> some View {
        let isActive = environment.settings.activeExtensionThemeID == theme.id
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.accentColor, theme.backgroundColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 44, height: 28)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .foregroundStyle(.primary)
                    Text(isActive ? "\(theme.sourceLabel), Active" : theme.sourceLabel)
                        .font(.caption2)
                        .foregroundStyle(isActive ? environment.settings.brandColor : .secondary)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                if isActive {
                    Button("Deactivate") {
                        environment.extensionThemes.clearActive()
                        environment.icloudSync.noteLocalChange()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button("Activate") {
                        environment.extensionThemes.apply(id: theme.id)
                        environment.icloudSync.noteLocalChange()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }

                Button("Remove", role: .destructive) {
                    environment.extensionThemes.remove(id: theme.id)
                    environment.icloudSync.noteLocalChange()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
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

// MARK: - Privacy

private struct PrivacySettingsPage: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
            Section {
                Toggle("Enable JavaScript by default", isOn: $settings.javaScriptEnabledByDefault)
                Toggle("Block media autoplay", isOn: $settings.blockAutoplay)
            } header: {
                Text("Page media")
            } footer: {
                Text("Autoplay blocking applies to new tabs. Use the JS button to toggle the current tab.")
            }

            Section {
                Toggle("Strip tracking parameters from URLs", isOn: $settings.stripTrackingParameters)
            } header: {
                Text("Tracking")
            } footer: {
                Text("Removes common trackers like utm_*, fbclid, and gclid. Focus Mode (⋯) also mutes media and hides cookie banners.")
            }
        }
        .navigationTitle("Privacy & media")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

// MARK: - Accounts

private struct AccountsSettingsPage: View {
    @Environment(AppEnvironment.self) private var environment
    var showsDoneButton: Bool

    var body: some View {
        Form {
            Section {
                Toggle("iCloud Sync", isOn: Binding(
                    get: { environment.icloudSync.isEnabled },
                    set: {
                        environment.icloudSync.isEnabled = $0
                        if $0 { environment.icloudSync.pushAll() }
                    }
                ))
                Button("Autofill Password for This Site") {
                    Task { await environment.autofillPasswordForActivePage() }
                }
                Button("Workspaces…") {
                    environment.showWorkspaces = true
                }
                #if os(macOS)
                Toggle("Vertical Tabs", isOn: Binding(
                    get: { environment.useVerticalTabs },
                    set: { environment.setVerticalTabsEnabled($0) }
                ))
                #endif
            } footer: {
                Text("iCloud Sync mirrors bookmarks, Reading List, history, open tabs, and appearance. Passwords use the system Keychain.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Accounts & sync")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

// MARK: - Homepage

private struct HomepageSettingsPage: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
            Section {
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
        }
        .navigationTitle("Homepage")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }
}

// MARK: - About

private struct AboutSettingsPage: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton: Bool

    var body: some View {
        @Bindable var settings = environment.settings
        Form {
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
            }

            Section {
                LabeledContent("Product", value: EditionBranding.productName(for: environment.settings.edition))
                LabeledContent("Version", value: appVersionLabel)
                LabeledContent("Edition", value: environment.settings.edition.displayName)
                LabeledContent(
                    "Page engine",
                    value: environment.resolvedEngine(for: environment.activeTab).displayName
                )
                LabeledContent("Website", value: BrowserConstants.productWebsiteHost)
                LabeledContent("Publisher", value: BrowserConstants.publisherName)
                Link("Open \(BrowserConstants.productWebsiteHost)", destination: BrowserConstants.productWebsiteURL)
                Button("Show Welcome Tour Again") {
                    settings.hasCompletedOnboarding = false
                    if showsDoneButton { dismiss() }
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("About")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(version) (\(build))"
    }
}
