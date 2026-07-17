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
            #if os(macOS)
                .frame(minWidth: 460, idealWidth: 520, minHeight: 640)
            #endif
        }
        .sheet(isPresented: $environment.showDownloads) {
            DownloadsView()
                .orielSheetChrome()
        }
        .sheet(isPresented: $environment.showSettings) {
            SettingsView()
                .orielSheetChrome()
        }
        .onChange(of: environment.settings.restorePreviousSession) { _, newValue in
            environment.sessionStore.restorePreviousSession = newValue
        }
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
                environment.showSettings = true
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
        VStack(spacing: 0) {
            if tab.isPrivate { privateBanner }
            if environment.tabs.tabs.count > 1 {
                macTabStrip(environment: environment)
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
            ToolbarItemGroup(placement: .navigation) {
                NavigationControlsView(tab: tab)
            }
            ToolbarItem(placement: .principal) {
                AddressBarView(tab: tab, searchEngine: environment.settings.searchEngine) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                }
                .frame(minWidth: 280, idealWidth: 520, maxWidth: 720)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    environment.tabs.createTab(select: true)
                    environment.wireTabPrivacyHooks()
                } label: {
                    Image(systemName: "plus")
                }
                .help("New Tab")

                shieldButton(environment: environment)

                Button {
                    environment.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")

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
        }
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
                            if item.isPrivate {
                                Image(systemName: "eyeglasses").font(.caption2)
                            }
                            Text(item.displayTitle).lineLimit(1)
                            if environment.tabs.tabs.count > 1 {
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
            Button("Reopen Closed Tab") {
                _ = environment.tabs.restoreClosedTab()
                environment.wireTabPrivacyHooks()
            }
            .disabled(!environment.tabs.canRestoreClosedTab)

            Divider()

            Button("Find in Page…") { environment.showFindInPage = true }
                .disabled(tab.isShowingStartPage)

            Button(tab.requestsDesktopSite ? "Request Mobile Website" : "Request Desktop Website") {
                tab.toggleDesktopSite()
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
            Button("Shields") { environment.showPrivacyShield = true }
            Button("Settings") { environment.showSettings = true }

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
                permissionManager: environment.permissions
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
        self.frame(minWidth: 420, minHeight: 480)
        #else
        self
        #endif
    }
}
