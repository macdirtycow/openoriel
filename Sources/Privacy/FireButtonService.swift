import Foundation

struct FireClearOptions: Equatable, Sendable {
    var history = true
    var cookiesAndSiteData = true
    var downloads = true
    var openLaterQueue = false
    var sitePermissions = false
    var closeTabs = false
    var closePrivateTabsOnly = false

    static let `default` = FireClearOptions()
}

@MainActor
enum FireButtonService {
    static func burn(
        options: FireClearOptions,
        environment: AppEnvironment
    ) async {
        if options.history {
            environment.history.clear()
        }
        if options.cookiesAndSiteData {
            await WebsiteDataCleaner.clearBrowsingData(
                in: environment.profiles.dataStore(isPrivateTab: false),
                includingCookies: true,
                includingCache: true,
                includingLocalStorage: true
            )
            // Also clear private/ephemeral jars that may still be alive in memory.
            await WebsiteDataCleaner.clearBrowsingData(
                in: .nonPersistent(),
                includingCookies: true,
                includingCache: true,
                includingLocalStorage: true
            )
            // CEF / Blink Native keeps a separate cookie jar.
            ChromiumNativeHost.clearEmbeddedBrowsingData()
        }
        if options.downloads {
            environment.downloads.clearAll()
        }
        if options.openLaterQueue {
            environment.linkQueue.clear()
        }
        if options.sitePermissions {
            environment.permissions.clearAll()
        }
        if options.closeTabs {
            environment.tabs.closeAllTabs(includingPrivate: true)
            WebViewPool.shared.releaseAll()
            environment.sessionStore.clear()
        } else if options.closePrivateTabsOnly {
            environment.tabs.closeAllPrivateTabs()
            // Keep the restore snapshot in sync with remaining tabs.
            environment.persistSessionNow()
        } else {
            // Do not delete session.json when tabs stay open — otherwise a force-quit
            // before the next persist leaves the next launch empty.
            environment.persistSessionNow()
        }
        environment.privacyStats.resetSessionCounters()
        environment.privacyStats.flush()
    }
}
