import SwiftUI

struct BrowserShellView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var environment = environment
        let tab = environment.tabs.activeTab

        Group {
            if let tab {
                #if os(macOS)
                macShell(tab: tab, environment: environment)
                #else
                if horizontalSizeClass == .regular {
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
        .sheet(isPresented: $environment.showAbout) {
            AboutOrielView()
                .orielSheetChrome()
        }
        .sheet(isPresented: $environment.showTabOverview) {
            TabOverviewView()
                .orielSheetChrome(preferLargeOnCompact: true)
        }
        .sheet(isPresented: $environment.showBookmarks) {
            BookmarksView()
                .orielSheetChrome()
        }
        .sheet(isPresented: $environment.showHistory) {
            HistoryView()
                .orielSheetChrome()
        }
        .sheet(isPresented: $environment.showPrivacyShield) {
            PrivacyShieldView()
                .orielSheetChrome(preferLargeOnCompact: true)
        }
        .sheet(isPresented: $environment.showDownloads) {
            DownloadsView()
                .orielSheetChrome()
        }
        .sheet(isPresented: $environment.showExtensions) {
            ExtensionsView()
                #if os(iOS)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                #else
                .frame(minWidth: 420, idealWidth: 520, minHeight: 380, idealHeight: 520)
                #endif
        }
        .sheet(isPresented: $environment.showSettings) {
            SettingsView(showsDoneButton: true)
                .orielSheetChrome(preferLargeOnCompact: true)
                #if os(macOS)
                .frame(minWidth: 360, idealWidth: 480, minHeight: 400, idealHeight: 560)
                #endif
        }
        .sheet(item: $environment.authPopup) { popup in
            AuthPopupView(state: popup)
                .orielSheetChrome(preferLargeOnCompact: true)
        }
        .onChange(of: environment.settings.restorePreviousSession) { _, newValue in
            environment.sessionStore.restorePreviousSession = newValue
        }
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
            content(for: tab, environment: environment)
            if environment.showFindInPage {
                findBar(environment: environment)
            }

            VStack(spacing: 8) {
                AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                    hideKeyboard()
                }

                HStack(spacing: 8) {
                    NavigationControlsView(tab: tab)
                    Spacer(minLength: 4)
                    trailingChrome(environment: environment, tab: tab, compact: true)
                }
            }
            .padding(.horizontal, OrielLayout.phoneChromePadding)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(.bar)
        }
    }

    // MARK: - iPad (regular width)

    @ViewBuilder
    private func iPadShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        VStack(spacing: 0) {
            if tab.isPrivate { privateBanner }

            HStack(spacing: 12) {
                NavigationControlsView(tab: tab)
                AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                    hideKeyboard()
                }
                trailingChrome(environment: environment, tab: tab, compact: false)
            }
            .padding(.horizontal, OrielLayout.padChromePadding)
            .padding(.vertical, 10)
            .background(.bar)

            progressBar(for: tab)
            content(for: tab, environment: environment)
            if environment.showFindInPage {
                findBar(environment: environment)
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    @ViewBuilder
    private func trailingChrome(environment: AppEnvironment, tab: BrowserTab, compact: Bool) -> some View {
        HStack(spacing: compact ? 10 : 14) {
            javaScriptButton(tab: tab)
            shieldButton(environment: environment)
            if !compact {
                Button {
                    environment.showDownloads = true
                } label: {
                    Image(systemName: environment.downloads.hasActiveDownloads ? "arrow.down.circle.fill" : "arrow.down.circle")
                }
                .accessibilityLabel("Downloads")
            }
            Button {
                openAppSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Change search engine, appearance, and more")
            chromeMenu(environment: environment, tab: tab)
            Button {
                environment.showTabOverview = true
            } label: {
                if compact {
                    Image(systemName: "square.on.square")
                        .accessibilityLabel("Tabs, \(environment.tabs.tabs.count)")
                } else {
                    Label("\(environment.tabs.tabs.count)", systemImage: "square.on.square")
                }
            }
            .accessibilityLabel("Tabs")
            .accessibilityValue("\(environment.tabs.tabs.count)")
        }
    }

    private func findBar(environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        return FindInPageBar(
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
    @ViewBuilder
    private func macShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        @Bindable var environment = environment
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 780
            VStack(spacing: 0) {
                if tab.isPrivate { privateBanner }
                if environment.tabs.tabs.count > 1 {
                    macTabStrip(environment: environment)
                }
                if isCompact {
                    macCompactChrome(tab: tab, environment: environment)
                }
                progressBar(for: tab)
                content(for: tab, environment: environment)
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
            .toolbar {
                if !isCompact {
                    ToolbarItemGroup(placement: .navigation) {
                        NavigationControlsView(tab: tab)
                    }
                    ToolbarItem(placement: .principal) {
                        AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                            tab.searchEngine = environment.settings.searchEngine
                            tab.submitAddressBar()
                        }
                        .frame(minWidth: 200, idealWidth: 520, maxWidth: 720)
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        // Settings first so it survives toolbar overflow in mid-size windows.
                        Button {
                            openAppSettings()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .help("Settings")

                        Button {
                            environment.tabs.createTab(select: true)
                            environment.wireTabPrivacyHooks()
                        } label: {
                            Image(systemName: "plus")
                        }
                        .help("New Tab")

                        shieldButton(environment: environment)
                        javaScriptButton(tab: tab)

                        Button {
                            environment.showExtensions = true
                        } label: {
                            Image(systemName: "puzzlepiece.extension")
                        }
                        .help("Extensions")

                        Button {
                            environment.showDownloads = true
                        } label: {
                            Image(systemName: environment.downloads.hasActiveDownloads ? "arrow.down.circle.fill" : "arrow.down.circle")
                        }
                        .help("Downloads")

                        Button {
                            environment.showTabOverview = true
                        } label: {
                            Image(systemName: "square.on.square")
                        }
                        .help("Tab Overview")

                        chromeMenu(environment: environment, tab: tab)
                    }
                } else {
                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            openAppSettings()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .help("Settings")
                    }
                }
            }
        }
    }

    /// Always-visible chrome when the window is too narrow for the full toolbar.
    private func macCompactChrome(tab: BrowserTab, environment: AppEnvironment) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                NavigationControlsView(tab: tab)
                AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                }
            }
            HStack(spacing: 12) {
                Button {
                    openAppSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                shieldButton(environment: environment)
                javaScriptButton(tab: tab)
                Button {
                    environment.showExtensions = true
                } label: {
                    Image(systemName: "puzzlepiece.extension")
                }
                .help("Extensions")
                Spacer(minLength: 0)
                Button {
                    environment.tabs.createTab(select: true)
                    environment.wireTabPrivacyHooks()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Tab")
                chromeMenu(environment: environment, tab: tab)
                Button {
                    environment.showTabOverview = true
                } label: {
                    Image(systemName: "square.on.square")
                }
                .help("Tab Overview")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func macTabStrip(environment: AppEnvironment) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
                            Text(item.displayTitle).lineLimit(1)
                            if environment.tabs.tabs.count > 1, !item.isPinned {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .onTapGesture { environment.tabs.closeTab(id: item.id) }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
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
        Text("Private Tab — history and session restore are off")
            .font(.caption.weight(.medium))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.purple.opacity(0.18))
            .accessibilityLabel("Private browsing tab")
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
        Button {
            tab.toggleJavaScript()
        } label: {
            Text("JS")
                .font(.caption.weight(.bold))
                .monospaced()
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    tab.javaScriptEnabled
                        ? Color.accentColor.opacity(0.18)
                        : Color.orange.opacity(0.22),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )
                .foregroundStyle(tab.javaScriptEnabled ? Color.primary : Color.orange)
                .overlay {
                    if !tab.javaScriptEnabled {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(Color.orange.opacity(0.7), lineWidth: 1)
                    }
                }
        }
        .accessibilityLabel(tab.javaScriptEnabled ? "JavaScript on" : "JavaScript off")
        .accessibilityHint("Toggles JavaScript for this tab and reloads the page")
        .accessibilityValue(tab.javaScriptEnabled ? "Enabled" : "Disabled")
        .help(tab.javaScriptEnabled ? "Disable JavaScript" : "Enable JavaScript")
        .disabled(tab.isShowingStartPage)
    }

    @ViewBuilder
    private func chromeMenu(environment: AppEnvironment, tab: BrowserTab) -> some View {
        Menu {
            Button("New Tab") {
                environment.tabs.createTab(select: true)
                environment.wireTabPrivacyHooks()
            }
            Button("New Private Tab") {
                environment.tabs.createPrivateTab(select: true)
                environment.wireTabPrivacyHooks()
            }
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

            Divider()

            Button("Find in Page…") { environment.showFindInPage = true }
                .disabled(tab.isShowingStartPage)

            Button(tab.isReaderMode ? "Exit Reader Mode" : "Reader Mode") {
                tab.toggleReaderMode()
            }
            .disabled(tab.isShowingStartPage)

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

            Button("Copy URL") {
                environment.copyCurrentURL()
            }
            .disabled(environment.shareURL == nil)

            if let shareURL = environment.shareURL {
                ShareLink(item: shareURL) {
                    Label("Share…", systemImage: "square.and.arrow.up")
                }
            }

            Divider()

            Button("Bookmark This Page") { environment.bookmarkActivePage() }
                .disabled(tab.isShowingStartPage || tab.isPrivate)

            Button("Bookmarks") { environment.showBookmarks = true }
            Button("History") { environment.showHistory = true }
            Button("Downloads") { environment.showDownloads = true }
            Button("Extensions") { environment.showExtensions = true }
            Button("Shields") { environment.showPrivacyShield = true }
            Button("Settings") { openAppSettings() }

            Divider()

            Button("Visit \(BrowserConstants.productWebsiteHost)") { tab.openProductSite() }
            Button("About Oriel") { environment.showAbout = true }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private func content(for tab: BrowserTab, environment: AppEnvironment) -> some View {
        let showStart = tab.isShowingStartPage && tab.navigation.lastErrorMessage == nil
        let showError = tab.navigation.lastErrorMessage != nil

        ZStack {
            BrowserWebView(
                tab: tab,
                contentRuleList: environment.contentBlocker.compiledList,
                blockThirdPartyCookies: environment.privacy.blockThirdPartyCookies,
                contentBlockingEnabled: environment.contentBlockingEnabled(for: tab),
                matchesBlockedHint: { url in
                    environment.contentBlocker.matchesBlockedHostHint(url)
                },
                onBlockedNavigation: {
                    environment.privacyStats.recordBlockedRequest()
                },
                onDownload: { url, name in
                    environment.downloads.enqueue(url: url, suggestedFileName: name)
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
                webExtensionController: environment.extensions.webExtensionControllerForConfiguration,
                blockAutoplay: environment.settings.blockAutoplay
            )
            .id(tab.id)
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
                .tint(Color.accentColor)
                .frame(height: 2)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: tab.navigation.estimatedProgress)
                .accessibilityLabel("Loading")
                .accessibilityValue("\(Int(tab.navigation.estimatedProgress * 100)) percent")
        } else {
            Color.clear.frame(height: 2)
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
