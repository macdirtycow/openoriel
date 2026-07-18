import SwiftUI

@main
struct OrielApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            // Theming must live in a View body — Scene.body does not track @Observable settings.
            OrielRootView(environment: environment)
                .onOpenURL { url in
                    environment.handleIncomingURL(url)
                }
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .commands {
            macCommands
        }
        #endif

        #if os(macOS)
        Settings {
            OrielSettingsRootView(environment: environment)
        }
        #endif
    }

    #if os(macOS)
    @CommandsBuilder
    private var macCommands: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("About Oriel") {
                environment.showAbout = true
            }
        }

        CommandGroup(after: .newItem) {
            Button("New Tab") {
                environment.tabs.createTab(select: true)
                environment.wireTabPrivacyHooks()
            }
            .keyboardShortcut("t", modifiers: .command)

            Button("New Private Tab") {
                environment.tabs.createPrivateTab(select: true)
                environment.wireTabPrivacyHooks()
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])

            Button("Close Tab") {
                environment.tabs.closeActiveTab()
            }
            .keyboardShortcut("w", modifiers: .command)

            Button("Reopen Closed Tab") {
                _ = environment.tabs.restoreClosedTab()
                environment.wireTabPrivacyHooks()
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
        }

        CommandGroup(after: .sidebar) {
            Button("Back") {
                environment.activeTab?.goBack()
            }
            .keyboardShortcut("[", modifiers: .command)

            Button("Forward") {
                environment.activeTab?.goForward()
            }
            .keyboardShortcut("]", modifiers: .command)

            Button("Home") {
                environment.activeTab?.goHome()
            }
            .keyboardShortcut("h", modifiers: [.command, .shift])

            Button("Reload") {
                environment.activeTab?.reload()
            }
            .keyboardShortcut("r", modifiers: .command)

            Button("Stop") {
                environment.activeTab?.stopLoading()
            }
            .keyboardShortcut(".", modifiers: .command)

            Button("Find…") {
                environment.showFindInPage = true
            }
            .keyboardShortcut("f", modifiers: .command)

            Button("Zoom In") {
                environment.activeTab?.zoomIn()
            }
            .keyboardShortcut("+", modifiers: .command)

            Button("Zoom Out") {
                environment.activeTab?.zoomOut()
            }
            .keyboardShortcut("-", modifiers: .command)

            Button("Actual Size") {
                environment.activeTab?.resetZoom()
            }
            .keyboardShortcut("0", modifiers: .command)

            Button("Reader Mode") {
                environment.activeTab?.toggleReaderMode()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button("Print…") {
                environment.activeTab?.printPage()
            }
            .keyboardShortcut("p", modifiers: .command)

            Button("Request Desktop Website") {
                environment.activeTab?.toggleDesktopSite()
            }

            Button("Show Tab Overview") {
                environment.showTabOverview = true
            }
            .keyboardShortcut("\\", modifiers: .command)

            Button("Bookmarks") {
                environment.showBookmarks = true
            }
            .keyboardShortcut("b", modifiers: [.command, .option])

            Button("History") {
                environment.showHistory = true
            }
            .keyboardShortcut("y", modifiers: .command)

            Button("Downloads") {
                environment.showDownloads = true
            }
            .keyboardShortcut("j", modifiers: [.command, .shift])

            Button("Extensions") {
                environment.showExtensions = true
            }
            .keyboardShortcut("e", modifiers: [.command, .shift])

            Button("Profiles…") {
                environment.showProfiles = true
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])

            Button("Shields") {
                environment.showPrivacyShield = true
            }
            .keyboardShortcut("i", modifiers: [.command, .shift])

            Button("Copy URL") {
                environment.copyCurrentURL()
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Bookmark This Page") {
                environment.bookmarkActivePage()
            }
            .keyboardShortcut("d", modifiers: .command)
        }
    }
    #endif
}

/// Root content view so appearance/accent observe `BrowserSettings` correctly.
private struct OrielRootView: View {
    @Bindable var environment: AppEnvironment

    private var showOnboarding: Binding<Bool> {
        Binding(
            get: { !environment.settings.hasCompletedOnboarding },
            set: { if !$0 { environment.settings.hasCompletedOnboarding = true } }
        )
    }

    var body: some View {
        BrowserShellView()
            .environment(environment)
            .orielTheming(settings: environment.settings)
            #if os(iOS)
            .fullScreenCover(isPresented: showOnboarding) {
                OnboardingView()
                    .environment(environment)
                    .orielTheming(settings: environment.settings)
                    .interactiveDismissDisabled()
            }
            #else
            .sheet(isPresented: showOnboarding) {
                OnboardingView()
                    .environment(environment)
                    .orielTheming(settings: environment.settings)
                    .frame(minWidth: 520, idealWidth: 560, minHeight: 620, idealHeight: 680)
                    .interactiveDismissDisabled()
            }
            #endif
    }
}

#if os(macOS)
private struct OrielSettingsRootView: View {
    @Bindable var environment: AppEnvironment

    var body: some View {
        SettingsView(showsDoneButton: false)
            .environment(environment)
            .orielTheming(settings: environment.settings)
            // Fit small displays / Stage Manager / split windows.
            .frame(minWidth: 360, idealWidth: 520, minHeight: 360, idealHeight: 560)
    }
}
#endif
