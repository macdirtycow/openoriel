import SwiftUI

@main
struct OrielApp: App {
    @State private var environment = AppEnvironment()

    var body: some Scene {
        WindowGroup {
            BrowserShellView()
                .environment(environment)
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
                }
                .keyboardShortcut("t", modifiers: .command)

                Button("Close Tab") {
                    environment.tabs.closeActiveTab()
                }
                .keyboardShortcut("w", modifiers: .command)

                Button("Reopen Closed Tab") {
                    _ = environment.tabs.restoreClosedTab()
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
            }

            CommandGroup(after: .sidebar) {
                Button("Reload") {
                    environment.activeTab?.reload()
                }
                .keyboardShortcut("r", modifiers: .command)

                Button("Stop") {
                    environment.activeTab?.stopLoading()
                }
                .keyboardShortcut(".", modifiers: .command)

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

                Button("Bookmark This Page") {
                    environment.bookmarkActivePage()
                }
                .keyboardShortcut("d", modifiers: .command)
            }
        }
        #endif
    }
}
