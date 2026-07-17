import SwiftUI

struct BrowserShellView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        @Bindable var environment = environment
        let tab = environment.tabs.activeTab

        Group {
            if let tab {
                #if os(macOS)
                macShell(tab: tab, environment: environment)
                #else
                iosShell(tab: tab, environment: environment)
                #endif
            } else {
                ProgressView()
            }
        }
        .sheet(isPresented: $environment.showAbout) {
            AboutOrielView()
                #if os(macOS)
                .frame(width: 420, height: 480)
                #endif
        }
        .sheet(isPresented: $environment.showTabOverview) {
            TabOverviewView()
                #if os(macOS)
                .frame(minWidth: 520, minHeight: 420)
                #endif
        }
        .sheet(isPresented: $environment.showBookmarks) {
            BookmarksView()
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 480)
                #endif
        }
        .sheet(isPresented: $environment.showHistory) {
            HistoryView()
                #if os(macOS)
                .frame(minWidth: 420, minHeight: 480)
                #endif
        }
        .sheet(isPresented: $environment.showPrivacyShield) {
            PrivacyShieldView()
                #if os(macOS)
                .frame(minWidth: 440, minHeight: 560)
                #endif
        }
        .onChange(of: environment.settings.restorePreviousSession) { _, newValue in
            environment.sessionStore.restorePreviousSession = newValue
        }
    }

    #if os(iOS)
    @ViewBuilder
    private func iosShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        VStack(spacing: 0) {
            if tab.isPrivate {
                privateBanner
            }
            progressBar(for: tab)
            content(for: tab, environment: environment)

            VStack(spacing: 8) {
                AddressBarView(tab: tab) {
                    tab.searchEngine = environment.settings.searchEngine
                    tab.submitAddressBar()
                    hideKeyboard()
                }

                HStack(spacing: 16) {
                    NavigationControlsView(tab: tab)
                    Spacer()
                    shieldButton(environment: environment)
                    chromeMenu(environment: environment, tab: tab)
                    Button {
                        environment.showTabOverview = true
                    } label: {
                        Label("\(environment.tabs.tabs.count)", systemImage: "square.on.square")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityLabel("Tabs")
                }
                .padding(.horizontal, 4)
            }
            .padding(.horizontal, OrielTheme.chromePadding)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(.bar)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    #endif

    #if os(macOS)
    @ViewBuilder
    private func macShell(tab: BrowserTab, environment: AppEnvironment) -> some View {
        VStack(spacing: 0) {
            if tab.isPrivate {
                privateBanner
            }
            if environment.tabs.tabs.count > 1 {
                macTabStrip(environment: environment)
            }
            progressBar(for: tab)
            content(for: tab, environment: environment)
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                NavigationControlsView(tab: tab)
            }
            ToolbarItem(placement: .principal) {
                AddressBarView(tab: tab) {
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
                                Image(systemName: "eyeglasses")
                                    .font(.caption2)
                            }
                            Text(item.displayTitle)
                                .lineLimit(1)
                            if environment.tabs.tabs.count > 1 {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .onTapGesture {
                                        environment.tabs.closeTab(id: item.id)
                                    }
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selected ? Color.accentColor.opacity(0.18) : Color.clear, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .background(.bar)
    }
    #endif

    private var privateBanner: some View {
        Text("Private Tab — history and session restore are off for this tab")
            .font(.caption.weight(.medium))
            .frame(maxWidth: .infinity)
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
            Button("Close Tab") {
                environment.tabs.closeActiveTab()
            }
            Button("Reopen Closed Tab") {
                _ = environment.tabs.restoreClosedTab()
                environment.wireTabPrivacyHooks()
            }
            .disabled(!environment.tabs.canRestoreClosedTab)

            Divider()

            Button("Bookmark This Page") {
                environment.bookmarkActivePage()
            }
            .disabled(URLParser.isStartPage(tab.navigation.url) || tab.isPrivate)

            Button("Bookmarks") { environment.showBookmarks = true }
            Button("History") { environment.showHistory = true }
            Button("Shields") { environment.showPrivacyShield = true }

            Divider()

            Button("Visit \(BrowserConstants.productWebsiteHost)") {
                tab.openProductSite()
            }
            Button("About Oriel") {
                environment.showAbout = true
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("More")
    }

    @ViewBuilder
    private func content(for tab: BrowserTab, environment: AppEnvironment) -> some View {
        ZStack {
            if URLParser.isStartPage(tab.navigation.url), tab.navigation.lastErrorMessage == nil {
                StartPageView(tab: tab)
            } else if let message = tab.navigation.lastErrorMessage {
                ErrorPageView(
                    message: message,
                    onRetry: { tab.reload() },
                    onHome: { tab.goHome() }
                )
            } else {
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
                    }
                )
                .id("\(tab.id)-\(environment.contentBlockingEnabled(for: tab))-\(environment.contentBlocker.isReady)")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func progressBar(for tab: BrowserTab) -> some View {
        if tab.navigation.isLoading && !URLParser.isStartPage(tab.navigation.url) {
            ProgressView(value: tab.navigation.estimatedProgress)
                .progressViewStyle(.linear)
                .tint(Color.accentColor)
                .frame(height: 2)
                .animation(.easeOut(duration: 0.15), value: tab.navigation.estimatedProgress)
        } else {
            Color.clear.frame(height: 2)
        }
    }
}
