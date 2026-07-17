import SwiftUI

@main
struct OrielApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            BrowserShellView()
                .environment(environment)
                .preferredColorScheme(environment.settings.appearance.colorScheme)
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        .commands {
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

                Button("Shields") {
                    environment.showPrivacyShield = true
                }
                .keyboardShortcut("i", modifiers: [.command, .shift])

                Button("Copy URL") {
                    environment.copyCurrentURL()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Settings…") {
                    environment.showSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Bookmark This Page") {
                    environment.bookmarkActivePage()
                }
                .keyboardShortcut("d", modifiers: .command)
            }
        }
        #endif
    }
}
