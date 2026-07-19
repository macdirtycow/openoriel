import SwiftUI

struct BrowserShellView: View {
    /// Prefer iPad chrome (top bar + tab strip) at this width and above — even in Split View.
    private static let padChromeMinWidth: CGFloat = 700

    @Environment(AppEnvironment.self) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var environment = environment
        let tab = environment.tabs.activeTab

        GeometryReader { proxy in
            Group {
                if let tab {
                    #if os(macOS)
                    macShell(tab: tab, environment: environment)
                    #else
                    if proxy.size.width >= Self.padChromeMinWidth {
                        iPadShell(tab: tab, environment: environment)
                    } else {
                        iPhoneShell(tab: tab, environment: environment)
                    }
                    #endif
                } else {
                    ProgressView("Starting Oriel…")
                        .accessibilityLabel("Starting Oriel")
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        #if os(iOS)
        .background {
            OrielTheme.chromeWash(
                accent: environment.settings.accentTheme,
                background: environment.settings.backgroundTheme,
                scheme: colorScheme,
                customAccent: environment.settings.usesExtensionTheme ? environment.settings.brandColor : nil,
                customBackground: environment.settings.customBackgroundColor
            )
            .ignoresSafeArea()
        }
        #endif
        .sheet(isPresented: $environment.showAbout) {
            AboutOrielView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showTabOverview) {
            TabOverviewView()
                .orielSheetChrome(preferLargeOnCompact: true)
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showBookmarks) {
            BookmarksView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showHistory) {
            HistoryView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showPrivacyShield) {
            PrivacyShieldView()
                .orielSheetChrome(preferLargeOnCompact: true)
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showDownloads) {
            DownloadsView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showExtensions) {
            ExtensionsView()
                .orielTheming(settings: environment.settings)
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #else
                .frame(minWidth: 420, idealWidth: 520, minHeight: 380, idealHeight: 520)
                #endif
        }
        .sheet(isPresented: $environment.showOrielStore) {
            NavigationStack {
                OrielStoreView(showsDoneButton: true)
            }
            .orielSheetChrome(preferLargeOnCompact: true)
            .orielTheming(settings: environment.settings)
            #if os(macOS)
            .frame(minWidth: 440, idealWidth: 560, minHeight: 420, idealHeight: 640)
            #endif
        }
        .sheet(isPresented: $environment.showSettings) {
            SettingsView(showsDoneButton: true)
                .orielSheetChrome(preferLargeOnCompact: true)
                .orielTheming(settings: environment.settings)
                #if os(macOS)
                .frame(minWidth: 360, idealWidth: 480, minHeight: 400, idealHeight: 560)
                #endif
        }
        .sheet(isPresented: $environment.showLinkQueue) {
            LinkQueueView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showFireButton) {
            FireButtonView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showTranslate) {
            TranslatePageView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showProfiles) {
            ProfilesView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showWorkspaces) {
            WorkspacesView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(isPresented: $environment.showPictureInPicturePicker) {
            PictureInPicturePickerView()
                .orielSheetChrome()
                .orielTheming(settings: environment.settings)
        }
        .sheet(item: $environment.authPopup) { popup in
            AuthPopupView(state: popup)
                .orielSheetChrome(preferLargeOnCompact: true)
                .orielTheming(settings: environment.settings)
        }
        .onChange(of: environment.settings.restorePreviousSession) { _, newValue in
            environment.sessionStore.restorePreviousSession = newValue
        }
        .onChange(of: environment.activeTab?.navigation.url) { _, newURL in
            environment.considerOrielStoreTip(for: newURL)
        }
        .onChange(of: environment.tabs.activeTabID) { _, _ in
            environment.considerOrielStoreTip(for: environment.activeTab?.navigation.url)
        }
        .alert(
            "Use Oriel Store?",
            isPresented: $environment.showOrielStoreTip
        ) {
            Button("Open Oriel Store") {
                environment.dismissOrielStoreTip(openStore: true)
            }
            Button("Keep browsing", role: .cancel) {
                environment.dismissOrielStoreTip(openStore: false)
            }
        } message: {
            Text(orielStoreTipMessage(for: environment.activeTab?.navigation.url))
        }
    }

    private func orielStoreTipMessage(for url: URL?) -> String {
        if UserAgentPolicy.isFirefoxAddonsURL(url) {
            return "Oriel Store searches Chrome, Firefox, and Safari in one list — easier than browsing Firefox Add-ons here."
        }
        return "Oriel Store searches Chrome, Firefox, and Safari in one list — easier than browsing the Chrome Web Store here."
    }

    private func openAppSettings() {
        environment.showSettings = true
    }

    // MARK: - iPhone (compact)

    #if os(iOS)
    @ViewBuilder
    private func iPhoneShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        VStack(spacing: 0) {
            if tab.isPrivate { privateBanner }
            progressBar(for: tab)
            mainContent(tab: tab, environment: environment)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    VStack(spacing: 0) {
                        if environment.showFindInPage {
                            findBar(environment: environment)
                        }
                        phoneBottomChrome(tab: tab, environment: environment)
                    }
                    .background(.bar)
                }
        }
    }

    private func phoneBottomChrome(tab: BrowserTab, environment: AppEnvironment) -> some View {
        let accent = environment.settings.brandColor
        return VStack(spacing: 10) {
            AddressBarView(
                tab: tab,
                searchEngine: environment.settings.searchEngine,
                suggestionsPlacement: .above
            ) {
                tab.searchEngine = environment.settings.searchEngine
                tab.submitAddressBar()
                hideKeyboard()
            }

            // One calm row: back/forward · shields · more · tabs (New Tab lives in the menu).
            HStack(spacing: 10) {
                NavigationControlsView(tab: tab, style: .compact, showsShields: false)
                Spacer(minLength: 12)
                phoneToolbarButton(
                    systemName: environment.privacy.contentBlockingEnabled ? "shield.lefthalf.filled" : "shield.slash",
                    label: "Privacy Shields",
                    accent: accent,
                    emphasized: environment.privacy.contentBlockingEnabled
                ) {
                    environment.showPrivacyShield = true
                }
                chromeMenu(
                    environment: environment,
                    tab: tab,
                    density: .phone,
                    size: OrielLayout.compactNavButtonSize,
                    accent: accent,
                    chromeStyled: false
                )
                phoneToolbarButton(
                    systemName: "square.on.square",
                    label: "Tabs",
                    accent: accent,
                    badge: "\(environment.tabs.tabs.count)"
                ) {
                    environment.showTabOverview = true
                }
            }
        }
        .padding(.horizontal, OrielLayout.phoneChromePadding)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    private func phoneToolbarButton(
        systemName: String,
        label: String,
        accent: Color,
        emphasized: Bool = false,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: systemName)
                    .font(.system(size: OrielLayout.phoneToolbarIconSize, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                if let badge {
                    Text(badge)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(
            OrielPhoneToolbarButtonStyle(
                isEnabled: true,
                isEmphasized: emphasized,
                accent: accent
            )
        )
        .accessibilityLabel(badge.map { "\(label), \($0)" } ?? label)
        .help(label)
    }

    // MARK: - iPad (regular width)

    @ViewBuilder
    private func iPadShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        VStack(spacing: 0) {
            if tab.isPrivate { privateBanner }

            if environment.tabs.tabs.count > 1 {
                iPadTabStrip(environment: environment)
            }

            HStack(spacing: 12) {
                NavigationControlsView(tab: tab, showsShields: true)
                AddressBarView(
                    tab: tab,
                    searchEngine: environment.settings.searchEngine,
                    suggestionsPlacement: .below
                ) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                    hideKeyboard()
                }
                padTrailingChrome(environment: environment, tab: tab)
            }
            .padding(.horizontal, OrielLayout.padChromePadding)
            .padding(.vertical, 10)
            .background(.bar)

            progressBar(for: tab)
            mainContent(tab: tab, environment: environment)
            if environment.showFindInPage {
                findBar(environment: environment)
            }
        }
    }

    private func padTrailingChrome(environment: AppEnvironment, tab: BrowserTab) -> some View {
        let accent = environment.settings.brandColor
        let size = OrielLayout.navButtonSize
        return HStack(spacing: 8) {
            ProfileSwitcherControl(style: .chip)
            chromeIconButton(
                systemName: "plus",
                label: "New Tab",
                accent: accent,
                size: size
            ) {
                environment.tabs.createTab(select: true)
                environment.wireTabPrivacyHooks()
            }
            chromeIconButton(
                systemName: environment.downloads.hasActiveDownloads ? "arrow.down.circle.fill" : "arrow.down.circle",
                label: "Downloads",
                accent: accent,
                size: size
            ) {
                environment.showDownloads = true
            }
            chromeIconButton(
                systemName: "flame.fill",
                label: "Fire — clear browsing data",
                accent: accent,
                size: size
            ) {
                environment.showFireButton = true
            }
            chromeMenu(environment: environment, tab: tab, density: .standard, size: size, accent: accent)
            chromeIconButton(
                systemName: "square.on.square",
                label: "Tabs",
                accent: accent,
                size: size,
                badge: "\(environment.tabs.tabs.count)"
            ) {
                environment.showTabOverview = true
            }
        }
    }

    private func iPadTabStrip(environment: AppEnvironment) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(environment.tabs.tabs) { item in
                    let selected = item.id == environment.tabs.activeTabID
                    Button {
                        environment.tabs.selectTab(id: item.id)
                    } label: {
                        HStack(spacing: 6) {
                            FaviconImage(pageURL: item.restorableURL, size: 12)
                            if item.isPinned {
                                Image(systemName: "pin.fill").font(.caption2)
                            }
                            if item.isPrivate {
                                Image(systemName: "eyeglasses").font(.caption2)
                            }
                            Text(item.displayTitle)
                                .font(.subheadline.weight(selected ? .semibold : .regular))
                                .lineLimit(1)
                            if environment.tabs.tabs.count > 1, !item.isPinned {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .onTapGesture { environment.tabs.closeTab(id: item.id) }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .frame(minWidth: 120, maxWidth: 220, alignment: .leading)
                        .background(
                            selected ? environment.settings.brandColor.opacity(0.16) : Color.primary.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    selected ? environment.settings.brandColor.opacity(0.35) : Color.primary.opacity(0.06),
                                    lineWidth: 1
                                )
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.displayTitle)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, OrielLayout.padChromePadding)
            .padding(.vertical, 8)
        }
        .background(.bar)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func chromeIconButton(
        systemName: String,
        label: String,
        accent: Color,
        size: CGFloat,
        emphasized: Bool = false,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemName)
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .monospacedDigit()
                }
            }
        }
        .buttonStyle(
            OrielChromeButtonStyle(
                isEnabled: true,
                isEmphasized: emphasized,
                accent: accent,
                size: size,
                expandsHorizontally: badge != nil
            )
        )
        .accessibilityLabel(label)
        .help(label)
    }

    @ViewBuilder
    private func findBar(environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        FindInPageBar(
            query: $environment.findQuery,
            onSubmit: { environment.performFind(forward: true) },
            onNext: { environment.performFind(forward: true) },
            onPrevious: { environment.performFind(forward: false) },
            onClose: { environment.closeFind() }
        )
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    /// Below this width we use in-content chrome so AppKit doesn’t dump a laundry-list overflow menu.
    private static let compactChromeWidth: CGFloat = 980

    @ViewBuilder
    private func macShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        GeometryReader { proxy in
            let isCompact = proxy.size.width < Self.compactChromeWidth
            HStack(spacing: 0) {
                if environment.useVerticalTabs, !isCompact, environment.tabs.tabs.count > 0 {
                    macVerticalTabStrip(environment: environment)
                        .frame(width: 220)
                }
                VStack(spacing: 0) {
                    if tab.isPrivate { privateBanner }
                    if !environment.useVerticalTabs, environment.tabs.tabs.count > 1 {
                        macTabStrip(environment: environment)
                    }
                    if isCompact {
                        macCompactChrome(tab: tab, environment: environment)
                    }
                    progressBar(for: tab)
                    mainContent(tab: tab, environment: environment)
                    if environment.showFindInPage {
                        FindInPageBar(
                            query: $environment.findQuery,
                            onSubmit: { environment.performFind(forward: true) },
                            onNext: { environment.performFind(forward: true) },
                            onPrevious: { environment.performFind(forward: false) },
                            onClose: { environment.closeFind() }
                        )
                    }
                }
            }
            .toolbar {
                if !isCompact {
                    ToolbarItemGroup(placement: .navigation) {
                        NavigationControlsView(tab: tab, style: .full)
                    }
                    ToolbarItem(placement: .principal) {
                        AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                            tab.searchEngine = environment.settings.searchEngine
                            tab.submitAddressBar()
                        }
                        .frame(minWidth: 240, idealWidth: 560, maxWidth: 760)
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        ProfileSwitcherControl(style: .icon)

                        Button {
                            environment.tabs.createTab(select: true)
                            environment.wireTabPrivacyHooks()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Tab")

                        extensionToolbarMenu(environment: environment)

                        Button {
                            environment.showTabOverview = true
                        } label: {
                            Image(systemName: "square.on.square")
                        }
                        .help("Tab Overview")

                        chromeMenu(environment: environment, tab: tab, density: .standard, chromeStyled: false)
                    }
                }
            }
        }
    }

    private func macVerticalTabStrip(environment: AppEnvironment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tabs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                ProfileSwitcherControl(style: .icon)
                Button {
                    environment.tabs.createTab(select: true)
                    environment.wireTabPrivacyHooks()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)
                .help("New Tab")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(environment.tabs.groups) { group in
                        let groupTabs = environment.tabs.tabs.filter { $0.groupID == group.id }
                        if !groupTabs.isEmpty {
                            Text(group.name)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(group.color)
                                .padding(.horizontal, 12)
                                .padding(.top, 8)
                            ForEach(groupTabs) { item in
                                macVerticalTabRow(item, environment: environment)
                            }
                        }
                    }
                    let ungrouped = environment.tabs.tabs.filter { $0.groupID == nil }
                    ForEach(ungrouped) { item in
                        macVerticalTabRow(item, environment: environment)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .background(.bar)
    }

    private func macVerticalTabRow(_ item: BrowserTab, environment: AppEnvironment) -> some View {
        let selected = item.id == environment.tabs.activeTabID
        return Button {
            environment.tabs.selectTab(id: item.id)
        } label: {
            HStack(spacing: 8) {
                FaviconImage(pageURL: item.restorableURL, size: 14)
                Text(item.displayTitle)
                    .lineLimit(1)
                    .font(.callout)
                Spacer(minLength: 0)
                if environment.tabs.tabs.count > 1, !item.isPinned {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .onTapGesture { environment.tabs.closeTab(id: item.id) }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                selected ? environment.settings.brandColor.opacity(0.16) : Color.clear,
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Compact Mac window: nav · address · tabs · more (New Tab / profile live in the menu).
    private func macCompactChrome(tab: BrowserTab, environment: AppEnvironment) -> some View {
        HStack(spacing: 10) {
            NavigationControlsView(tab: tab, style: .compact)

            AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                tab.searchEngine = environment.settings.searchEngine
                tab.submitAddressBar()
            }
            .frame(maxWidth: .infinity)

            Button {
                environment.showTabOverview = true
            } label: {
                Image(systemName: "square.on.square")
            }
            .help("Tabs")
            .buttonStyle(.borderless)

            chromeMenu(
                environment: environment,
                tab: tab,
                density: .standard,
                chromeStyled: false
            )
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    @ViewBuilder
    private func extensionToolbarMenu(environment: AppEnvironment) -> some View {
        Menu {
            if environment.extensions.extensions.isEmpty {
                Text("No extensions installed")
            } else {
                ForEach(environment.extensions.extensions) { item in
                    Button(item.displayName) {
                        environment.extensions.openAction(for: item.id)
                    }
                    .disabled(!item.isEnabled)
                }
                Divider()
            }
            Button("Manage Extensions…") {
                environment.showExtensions = true
            }
        } label: {
            Image(systemName: "puzzlepiece.extension")
        }
        .help("Extensions")
        .accessibilityLabel("Extensions")
    }

    private func macTabStrip(environment: AppEnvironment) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 3) {
                ForEach(environment.tabs.tabs) { item in
                    let selected = item.id == environment.tabs.activeTabID
                    Button {
                        environment.tabs.selectTab(id: item.id)
                    } label: {
                        HStack(spacing: 6) {
                            FaviconImage(pageURL: item.restorableURL, size: 12)
                            if item.isPinned {
                                Image(systemName: "pin.fill").font(.caption2)
                            }
                            if item.isPrivate {
                                Image(systemName: "eyeglasses").font(.caption2)
                            }
                            Text(item.displayTitle)
                                .font(.callout)
                                .lineLimit(1)
                            if environment.tabs.tabs.count > 1, !item.isPinned {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.secondary)
                                    .onTapGesture { environment.tabs.closeTab(id: item.id) }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .frame(minWidth: 120, maxWidth: 220, alignment: .leading)
                        .background(
                            selected
                                ? environment.settings.brandColor.opacity(0.14)
                                : Color.primary.opacity(0.035),
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.displayTitle)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
    #endif

    // MARK: - Shared

    private var privateBanner: some View {
        HStack(spacing: 6) {
            Image(systemName: "eyeglasses")
                .font(.caption.weight(.semibold))
            Text("Private Tab")
                .font(.caption.weight(.bold))
            Text("·")
                .foregroundStyle(environment.settings.brandColor.opacity(0.55))
            Text("History and restore are off")
                .font(.caption.weight(.medium))
                .opacity(0.85)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .foregroundStyle(environment.settings.brandColor)
        .background(environment.settings.brandColor.opacity(0.12))
        .accessibilityLabel("Private browsing tab")
        .accessibilityHint("History and session restore are off")
    }

    private func shieldButton(environment: AppEnvironment) -> some View {
        Button {
            environment.showPrivacyShield = true
        } label: {
            Image(systemName: environment.privacy.contentBlockingEnabled ? "shield.lefthalf.filled" : "shield.slash")
        }
        .accessibilityLabel("Privacy Shields")
        .accessibilityHint("Shows tracker blocking, HTTPS upgrades, and site permissions")
        .help("Privacy Shields")
    }

    private func javaScriptButton(tab: BrowserTab) -> some View {
        let accent = environment.settings.brandColor
        return Button {
            tab.toggleJavaScript()
        } label: {
            Text("JS")
                .font(.caption.weight(.bold))
                .monospaced()
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    tab.javaScriptEnabled
                        ? accent.opacity(0.18)
                        : Color.orange.opacity(0.22),
                    in: RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
                )
                .foregroundStyle(tab.javaScriptEnabled ? Color.primary : Color.orange)
                .overlay {
                    RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
                        .strokeBorder(
                            tab.javaScriptEnabled ? accent.opacity(0.35) : Color.orange.opacity(0.7),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.javaScriptEnabled ? "JavaScript on" : "JavaScript off")
        .accessibilityHint("Toggles JavaScript for this tab and reloads the page")
        .accessibilityValue(tab.javaScriptEnabled ? "Enabled" : "Disabled")
        .help(tab.javaScriptEnabled ? "Disable JavaScript" : "Enable JavaScript")
        .disabled(tab.isShowingStartPage)
    }

    private enum ChromeMenuDensity {
        /// iPhone: nested groups, short top-level list.
        case phone
        /// iPad / macOS (wide or compact) — nested Tab / Page / Library / Add-ons.
        case standard
        /// Narrow macOS window (same menu hierarchy as `.standard`).
        case macCompact
    }

    @ViewBuilder
    private func chromeMenu(
        environment: AppEnvironment,
        tab: BrowserTab,
        density: ChromeMenuDensity,
        size: CGFloat = OrielLayout.navButtonSize,
        accent: Color = OrielTheme.brandTeal,
        chromeStyled: Bool = true
    ) -> some View {
        Menu {
            switch density {
            case .phone:
                phoneChromeMenuContent(environment: environment, tab: tab)
            case .macCompact, .standard:
                // Narrow macOS windows share the same nested hierarchy as iPad / wide Mac.
                standardChromeMenuContent(environment: environment, tab: tab)
            }
        } label: {
            Group {
                if density == .phone {
                    Image(systemName: "ellipsis")
                        .font(.system(size: OrielLayout.phoneToolbarIconSize, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                } else {
                    Image(systemName: chromeStyled ? "ellipsis" : "ellipsis.circle")
                        .symbolRenderingMode(.hierarchical)
                        .imageScale(.medium)
                }
            }
        }
        .modifier(ChromeMenuButtonStyleModifier(
            chromeStyled: chromeStyled && density != .phone,
            size: size,
            accent: accent,
            phoneToolbar: density == .phone
        ))
        .accessibilityLabel("More")
        .help("More")
    }

    @ViewBuilder
    private func phoneChromeMenuContent(environment: AppEnvironment, tab: BrowserTab) -> some View {
        Button("New Tab", systemImage: "plus") {
            environment.tabs.createTab(select: true)
            environment.wireTabPrivacyHooks()
        }
        Button("New Private Tab", systemImage: "eyeglasses") {
            environment.tabs.createPrivateTab(select: true)
            environment.wireTabPrivacyHooks()
        }

        Menu("Tab", systemImage: "square.on.square") {
            Button("Duplicate Tab") {
                environment.tabs.duplicateActiveTab()
                environment.wireTabPrivacyHooks()
            }
            Button("Close Tab") { environment.tabs.closeActiveTab() }
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                environment.tabs.togglePin(id: tab.id)
            }
            Button("Reopen Closed Tab") {
                _ = environment.tabs.restoreClosedTab()
                environment.wireTabPrivacyHooks()
            }
            .disabled(!environment.tabs.canRestoreClosedTab)
        }

        Divider()

        Menu("Page", systemImage: "doc.text") {
            pageMenuContent(environment: environment, tab: tab, includeWorkspaces: false)
        }

        Button("Bookmark This Page", systemImage: "bookmark") {
            environment.bookmarkActivePage()
        }
        .disabled(tab.isShowingStartPage || tab.isPrivate)
        if let shareURL = environment.shareURL {
            ShareLink(item: shareURL) {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        Menu("Library", systemImage: "books.vertical") {
            Button("Bookmarks") { environment.showBookmarks = true }
            Button("History") { environment.showHistory = true }
            Button("Downloads") { environment.showDownloads = true }
            Button(environment.linkQueue.count == 0 ? "Open Later" : "Open Later (\(environment.linkQueue.count))") {
                environment.showLinkQueue = true
            }
            Button("Add Page to Open Later") {
                environment.enqueueCurrentPageForLater()
            }
            .disabled(tab.isShowingStartPage)
        }

        if environment.extensions.isSupported {
            Menu("Add-ons", systemImage: "puzzlepiece.extension") {
                Button("Oriel Store") { environment.showOrielStore = true }
                Button("Extensions") { environment.showExtensions = true }
            }
        }

        Divider()

        Button("Profiles…", systemImage: "person.crop.circle") {
            environment.showProfiles = true
        }
        Button("Settings", systemImage: "gearshape") { openAppSettings() }
        Button("Fire…", systemImage: "flame", role: .destructive) {
            environment.showFireButton = true
        }
    }

    @ViewBuilder
    private func standardChromeMenuContent(environment: AppEnvironment, tab: BrowserTab) -> some View {
        Button("New Tab", systemImage: "plus") {
            environment.tabs.createTab(select: true)
            environment.wireTabPrivacyHooks()
        }
        Button("New Private Tab", systemImage: "eyeglasses") {
            environment.tabs.createPrivateTab(select: true)
            environment.wireTabPrivacyHooks()
        }

        Menu("Tab", systemImage: "square.on.square") {
            Button("Duplicate Tab") {
                environment.tabs.duplicateActiveTab()
                environment.wireTabPrivacyHooks()
            }
            Button("Close Tab") { environment.tabs.closeActiveTab() }
            Button(tab.isPinned ? "Unpin Tab" : "Pin Tab") {
                environment.tabs.togglePin(id: tab.id)
            }
            Button("Reopen Closed Tab") {
                _ = environment.tabs.restoreClosedTab()
                environment.wireTabPrivacyHooks()
            }
            .disabled(!environment.tabs.canRestoreClosedTab)
        }

        Divider()

        Menu("Page", systemImage: "doc.text") {
            pageMenuContent(environment: environment, tab: tab, includeWorkspaces: true)
        }

        Button("Bookmark This Page", systemImage: "bookmark") {
            environment.bookmarkActivePage()
        }
        .disabled(tab.isShowingStartPage || tab.isPrivate)
        Button("Copy URL", systemImage: "link") {
            environment.copyCurrentURL()
        }
        .disabled(environment.shareURL == nil)
        if let shareURL = environment.shareURL {
            ShareLink(item: shareURL) {
                Label("Share…", systemImage: "square.and.arrow.up")
            }
        }

        Divider()

        Menu("Library", systemImage: "books.vertical") {
            Button("Bookmarks") { environment.showBookmarks = true }
            Button("History") { environment.showHistory = true }
            Button("Downloads") { environment.showDownloads = true }
            Button(environment.linkQueue.count == 0 ? "Open Later" : "Open Later (\(environment.linkQueue.count))") {
                environment.showLinkQueue = true
            }
            Button("Add Page to Open Later") {
                environment.enqueueCurrentPageForLater()
            }
            .disabled(tab.isShowingStartPage)
        }

        if environment.extensions.isSupported {
            Menu("Add-ons", systemImage: "puzzlepiece.extension") {
                Button("Oriel Store") { environment.showOrielStore = true }
                Button("Extensions") { environment.showExtensions = true }
            }
        }

        Button("Shields", systemImage: "shield.lefthalf.filled") {
            environment.showPrivacyShield = true
        }
        Button("Fire…", systemImage: "flame", role: .destructive) {
            environment.showFireButton = true
        }
        Button("Profiles…", systemImage: "person.crop.circle") {
            environment.showProfiles = true
        }
        Button("Settings", systemImage: "gearshape") { openAppSettings() }

        Divider()

        Button("Visit \(BrowserConstants.productWebsiteHost)") { tab.openProductSite() }
        Button("About Oriel") { environment.showAbout = true }
    }

    @ViewBuilder
    private func pageMenuContent(
        environment: AppEnvironment,
        tab: BrowserTab,
        includeWorkspaces: Bool
    ) -> some View {
        Button("Find in Page…") { environment.showFindInPage = true }
            .disabled(tab.isShowingStartPage)
        Button(tab.isReaderMode ? "Exit Reader Mode" : "Reader Mode") {
            tab.toggleReaderMode()
        }
        .disabled(tab.isShowingStartPage)
        Button(environment.isSplitViewActive ? "Close Split View" : "Open Split View") {
            if environment.isSplitViewActive {
                environment.closeSplitView()
            } else {
                environment.openSplitView()
            }
        }
        Button("Picture in Picture…") {
            environment.showPictureInPicturePicker = true
        }
        .disabled(tab.isShowingStartPage)
        Button("Show Media Controls") {
            tab.enableMediaControls()
        }
        .disabled(tab.isShowingStartPage)
        if includeWorkspaces {
            Button("Workspaces…") {
                environment.showWorkspaces = true
            }
        }
        Button(tab.forceDarkEnabled ? "Disable Force Dark" : "Force Dark on Page") {
            tab.toggleForceDark()
        }
        .disabled(tab.isShowingStartPage)
        Button("Zoom In") { tab.zoomIn() }
            .disabled(tab.isShowingStartPage)
        Button("Zoom Out") { tab.zoomOut() }
            .disabled(tab.isShowingStartPage)
        Button("Actual Size") { tab.resetZoom() }
            .disabled(tab.isShowingStartPage || tab.zoomFactor == 1.0)
        Button("Print…") { tab.printPage() }
            .disabled(tab.isShowingStartPage)
        Button(tab.requestsDesktopSite ? "Request Mobile Website" : "Request Desktop Website") {
            tab.toggleDesktopSite()
        }
        .disabled(tab.isShowingStartPage)
        Button(tab.javaScriptEnabled ? "Disable JavaScript" : "Enable JavaScript") {
            tab.toggleJavaScript()
        }
        .disabled(tab.isShowingStartPage)
        Button(tab.isFocusMode ? "Exit Focus Mode" : "Focus Mode") {
            tab.toggleFocusMode()
        }
        .disabled(tab.isShowingStartPage)
        Button("Translate Page…") {
            environment.showTranslate = true
        }
        .disabled(tab.isShowingStartPage)
        Button("Install as Web App") {
            Task { await environment.installCurrentPageAsWebApp() }
        }
        .disabled(tab.isShowingStartPage)
        Button("Autofill Password…") {
            Task { await environment.autofillPasswordForActivePage() }
        }
        .disabled(tab.isShowingStartPage)
        Button("Hide Element…") {
            tab.startElementPicker()
        }
        .disabled(tab.isShowingStartPage)
        Button("Clear Hidden Elements on Site") {
            environment.elementHide.clear(host: tab.navigation.url?.host)
            tab.reload()
        }
        .disabled(tab.isShowingStartPage)
        Button("Copy URL") { environment.copyCurrentURL() }
            .disabled(environment.shareURL == nil)
        Button("Reload") { tab.reload() }
            .disabled(tab.isShowingStartPage)
        Button("Home") { tab.goHome() }
            .disabled(tab.isShowingStartPage)
    }

    @ViewBuilder
    private func mainContent(tab: BrowserTab, environment: AppEnvironment) -> some View {
        VStack(spacing: 0) {
            if tab.isReaderMode {
                readerChromeBar(tab: tab)
            }
            if let secondary = environment.splitTab {
                GeometryReader { proxy in
                    let useVerticalSplit = proxy.size.width < 720
                    Group {
                        if useVerticalSplit {
                            VStack(spacing: 0) {
                                splitPane(tab: tab, environment: environment, isSecondary: false)
                                splitHandle(isVertical: true)
                                splitPane(tab: secondary, environment: environment, isSecondary: true)
                            }
                        } else {
                            HStack(spacing: 0) {
                                splitPane(tab: tab, environment: environment, isSecondary: false)
                                splitHandle(isVertical: false)
                                splitPane(tab: secondary, environment: environment, isSecondary: true)
                            }
                        }
                    }
                }
            } else {
                content(for: tab, environment: environment)
            }
        }
    }

    @ViewBuilder
    private func splitPane(tab: BrowserTab, environment: AppEnvironment, isSecondary: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(tab.displayTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if isSecondary {
                    Button("Focus") {
                        environment.tabs.selectTab(id: tab.id)
                        environment.splitTabID = environment.tabs.tabs.first(where: { $0.id != tab.id })?.id
                    }
                    .font(.caption2)
                    Button {
                        environment.closeSplitView()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .font(.caption2)
                    .accessibilityLabel("Close Split View")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.bar)
            content(for: tab, environment: environment)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func splitHandle(isVertical: Bool) -> some View {
        Group {
            if isVertical {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(height: 1)
            } else {
                Rectangle()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 1)
            }
        }
    }

    private func webViewPoolConfigKey(environment: AppEnvironment) -> String {
        "fp\(environment.privacy.fingerprintingProtection)-ap\(environment.settings.blockAutoplay)-p\(environment.profiles.activeProfileID.uuidString)"
    }

    private func protectedWebViewTabIDs(environment: AppEnvironment) -> Set<UUID> {
        var ids = Set<UUID>()
        if let active = environment.tabs.activeTabID {
            ids.insert(active)
        }
        if let split = environment.splitTabID {
            ids.insert(split)
        }
        return ids
    }

    private func readerChromeBar(tab: BrowserTab) -> some View {
        HStack(spacing: 12) {
            Text("Reader")
                .font(.subheadline.weight(.semibold))
            Spacer()
            Button("A") {
                tab.setReaderFontSize("sm")
            }
            .font(.caption.weight(.bold))
            Button("A") {
                tab.setReaderFontSize("md")
            }
            .font(.body.weight(.bold))
            Button("A") {
                tab.setReaderFontSize("lg")
            }
            .font(.title3.weight(.bold))
            Button("Done") {
                tab.toggleReaderMode()
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func content(for tab: BrowserTab, environment: AppEnvironment) -> some View {
        let showStart = tab.isShowingStartPage && tab.navigation.lastErrorMessage == nil
        let showError = tab.navigation.lastErrorMessage != nil

        ZStack {
            BrowserWebView(
                tab: tab,
                contentRuleLists: environment.contentBlocker.compiledLists,
                blockThirdPartyCookies: environment.privacy.blockThirdPartyCookies,
                fingerprintingProtection: environment.privacy.fingerprintingProtection,
                contentBlockingEnabled: environment.contentBlockingEnabled(for: tab),
                trackerProbeHosts: environment.contentBlocker.trackerProbeHosts(),
                matchesBlockedHint: { url in
                    environment.contentBlocker.matchesBlockedHostHint(url)
                },
                onBlockedNavigation: { blockedURL in
                    let cookieRelated = PrivacyStats.looksCookieRelated(blockedURL)
                        || environment.privacy.blockThirdPartyCookies
                    environment.privacyStats.recordBlockedRequest(url: blockedURL, cookieRelated: cookieRelated)
                },
                onDownload: { url, name in
                    environment.downloads.enqueue(
                        url: url,
                        suggestedFileName: name,
                        cookieStore: environment.profiles.dataStore(isPrivateTab: tab.isPrivate).httpCookieStore
                    )
                    environment.showDownloads = true
                },
                permissionManager: environment.permissions,
                onPopupCreated: { webView in
                    environment.presentAuthPopup(webView)
                },
                onPopupClosed: { _ in
                    environment.dismissAuthPopup()
                },
                onPopupTitleChanged: { title in
                    environment.updateAuthPopupTitle(title)
                },
                onOpenURLInNewTab: { url in
                    environment.openURLInNewTab(url, isPrivate: tab.isPrivate)
                },
                onEnqueueURLForLater: { url in
                    environment.enqueueLinkForLater(url: url)
                },
                shouldStripTracking: {
                    environment.settings.stripTrackingParameters
                },
                onElementHidden: { host, selector in
                    environment.elementHide.add(host: host, cssSelector: selector)
                },
                onInstallChromeExtension: { extensionID in
                    Task { @MainActor in
                        await environment.extensions.installFromChromeWebStore(extensionID: extensionID)
                        environment.showExtensions = true
                    }
                },
                onInstallFirefoxAddon: { slug in
                    Task { @MainActor in
                        await environment.extensions.installFromFirefoxAMO(slugOrID: slug)
                        environment.showExtensions = true
                    }
                },
                onManageChromeExtensions: {
                    environment.showExtensions = true
                },
                webExtensionController: environment.extensions.webExtensionControllerForConfiguration,
                blockAutoplay: environment.settings.blockAutoplay,
                chromeWebStoreInstallEnabled: environment.extensions.isSupported,
                // Union extensions + themes so CWS/AMO show “Installed” for theme-only packages too.
                installedChromeStoreIDs: Array(
                    Set(
                        environment.extensions.installedChromeStoreIDs
                            + environment.extensionThemes.installedChromeStoreIDs
                    )
                ).sorted(),
                installedFirefoxSlugs: Array(
                    Set(
                        environment.extensions.installedFirefoxSlugs
                            + environment.extensionThemes.installedFirefoxSlugs
                    )
                ).sorted(),
                applyContentBlocking: { webView, enabled in
                    environment.contentBlocker.apply(to: webView, enabled: enabled)
                },
                contentBlockerGeneration: environment.contentBlocker.generation,
                websiteDataStore: environment.profiles.dataStore(isPrivateTab: tab.isPrivate),
                poolConfigKey: webViewPoolConfigKey(environment: environment),
                protectedTabIDs: protectedWebViewTabIDs(environment: environment)
            )
            // Remount only when the WKWebView configuration must change.
            // Do NOT key on contentBlocker.generation — that wiped back/forward history
            // whenever filter lists finished compiling (rules re-attach in updateWebView).
            // Tab switches keep history via WebViewPool even when this view leaves the hierarchy.
            .id("\(tab.id.uuidString)-\(webViewPoolConfigKey(environment: environment))")
            .opacity(showStart || showError ? 0 : 1)
            .allowsHitTesting(!(showStart || showError))
            .accessibilityHidden(showStart || showError)

            if showStart {
                StartPageView(tab: tab)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            } else if let message = tab.navigation.lastErrorMessage {
                ErrorPageView(
                    message: message,
                    onRetry: { tab.reload() },
                    onHome: { tab.goHome() }
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showStart)
    }

    @ViewBuilder
    private func progressBar(for tab: BrowserTab) -> some View {
        if tab.navigation.isLoading && !tab.isShowingStartPage {
            ProgressView(value: tab.navigation.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(environment.settings.brandColor)
                .frame(height: 2)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: tab.navigation.estimatedProgress)
                .accessibilityLabel("Loading")
                .accessibilityValue("\(Int(tab.navigation.estimatedProgress * 100)) percent")
        } else {
            Color.clear.frame(height: 2)
        }
    }
}

// MARK: - Overflow menu chrome

private struct ChromeMenuButtonStyleModifier: ViewModifier {
    var chromeStyled: Bool
    var size: CGFloat
    var accent: Color
    var phoneToolbar: Bool = false

    @ViewBuilder
    func body(content: Content) -> some View {
        if phoneToolbar {
            content.buttonStyle(OrielPhoneToolbarButtonStyle())
        } else if chromeStyled {
            content.buttonStyle(
                OrielChromeButtonStyle(
                    isEnabled: true,
                    isEmphasized: false,
                    accent: accent,
                    size: size
                )
            )
        } else {
            content.buttonStyle(.borderless)
        }
    }
}

// MARK: - Sheet presentation helpers

private extension View {
    @ViewBuilder
    func orielSheetChrome(preferLargeOnCompact: Bool = false) -> some View {
        #if os(iOS)
        self
            .presentationDetents(preferLargeOnCompact ? [.large] : [.medium, .large])
            .presentationDragIndicator(.visible)
        #elseif os(macOS)
        self.frame(minWidth: 480, idealWidth: 560, minHeight: 420, idealHeight: 560)
        #else
        self
        #endif
    }
}
