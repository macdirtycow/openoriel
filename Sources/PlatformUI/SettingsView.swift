import SwiftUI

struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// When true, show a Done button (sheet). Native macOS Settings window can omit it.
    var showsDoneButton: Bool = true
    @State private var showProfilesSheet = false

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
                    .onChange(of: settings.appearance) { _, _ in
                        environment.icloudSync.noteLocalChange()
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent color")
                            .font(.subheadline.weight(.semibold))
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 8)], spacing: 8) {
                            ForEach(BrowserAccentTheme.allCases) { theme in
                                Button {
                                    settings.accentTheme = theme
                                    environment.icloudSync.noteLocalChange()
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
                                // Keep Appearance in sync with backgrounds that lock contrast,
                                // and reset to System for adaptive themes (Mist/Aurora).
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
                    Text("Accent colors tint buttons and Shields. Soft, Paper, and Sand stay light; Midnight stays dark. Mist and Aurora follow System appearance.")
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

                Section {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title2)
                                .foregroundStyle(settings.brandColor)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(environment.profiles.activeProfile.name)
                                    .font(.headline)
                                Text("Active profile · isolated cookies & site data")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        ProfileSwitcherControl(style: .chip)
                        Button {
                            if showsDoneButton {
                                environment.showProfiles = true
                                dismiss()
                            } else {
                                showProfilesSheet = true
                            }
                        } label: {
                            Label("Manage Profiles…", systemImage: "person.2")
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Profiles")
                } footer: {
                    Text("Switch profiles from the toolbar chip, start page, or here. Each profile keeps its own logins.")
                        .fixedSize(horizontal: false, vertical: true)
                }

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
                        if showsDoneButton {
                            environment.showWorkspaces = true
                            dismiss()
                        } else {
                            environment.showWorkspaces = true
                        }
                    }
                    #if os(macOS)
                    Toggle("Vertical Tabs", isOn: Binding(
                        get: { environment.useVerticalTabs },
                        set: { environment.setVerticalTabsEnabled($0) }
                    ))
                    #endif
                } header: {
                    Text("Accounts & layout")
                } footer: {
                    Text("iCloud Sync mirrors bookmarks, Open Later, history, open tabs, and appearance settings via iCloud Key-Value storage. Workspaces keep separate tab sets on this device. Passwords use the system Keychain picker.")
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section {
                    let browser = environment.defaultBrowser
                    VStack(alignment: .leading, spacing: 10) {
                        Text(browser.platformGuidance)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        if let status = browser.lastStatusMessage {
                            Label(status, systemImage: browser.isDefaultBrowser ? "checkmark.seal.fill" : "safari")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        if let error = browser.lastError {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }

                        if browser.canSetAsDefaultDirectly {
                            Button("Set Oriel as Default Browser") {
                                browser.promoteToDefaultBrowser()
                            }
                            Button("Open System Settings…") {
                                browser.openDefaultBrowserSettings()
                            }
                        } else {
                            Button("Open Default Browser Settings") {
                                browser.promoteToDefaultBrowser()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .onAppear { browser.refreshStatus() }
                } header: {
                    Text("Default browser")
                } footer: {
                    #if os(macOS)
                    Text("Oriel registers for http and https links so it can be chosen as your Mac’s default browser.")
                        .fixedSize(horizontal: false, vertical: true)
                    #else
                    Text("Apple requires the Default Browser entitlement before Oriel appears in Settings → Apps → Default Browser App. See docs/ENTITLEMENTS.md.")
                        .fixedSize(horizontal: false, vertical: true)
                    #endif
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
                    if environment.extensions.isSupported {
                        Button {
                            environment.openURLInNewTab(BrowserConstants.chromeWebStoreURL)
                            if showsDoneButton {
                                dismiss()
                            }
                        } label: {
                            Label("Browse Chrome Web Store", systemImage: "safari")
                        }
                    }
                } header: {
                    Text("Extensions")
                } footer: {
                    if environment.extensions.isSupported {
                        Text("Install Chrome Web Store or WebExtension packages (.zip / .crx / folder with manifest.json). Safari App Store extensions cannot run outside Safari.")
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(environment.extensions.lastError
                              ?? "Web extensions require macOS 15.4+ or iOS 18.4+.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
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
                    Button("Show Welcome Tour Again") {
                        settings.hasCompletedOnboarding = false
                        if showsDoneButton { dismiss() }
                    }
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
