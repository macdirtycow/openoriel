import Foundation
import Observation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Registers Oriel as a browser for http/https and helps users set it as the system default.
@Observable
@MainActor
final class DefaultBrowserService {
    private(set) var isDefaultForHTTP = false
    private(set) var isDefaultForHTTPS = false
    private(set) var lastStatusMessage: String?
    private(set) var lastError: String?

    var isDefaultBrowser: Bool {
        isDefaultForHTTP && isDefaultForHTTPS
    }

    /// macOS can claim the default handler immediately. On iOS/iPadOS Apple requires the
    /// managed `com.apple.developer.web-browser` entitlement before Oriel appears in
    /// Settings → Apps → Default Browser App.
    var canSetAsDefaultDirectly: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    var platformGuidance: String {
        #if os(macOS)
        """
        Oriel can register itself as the default app for http and https links. \
        After you confirm in System Settings, links from Mail, Messages, and other apps open here.
        """
        #else
        """
        On iPhone and iPad, Apple only lists browsers that hold the Default Browser entitlement. \
        Once that entitlement is approved for Oriel, open Settings → Apps → Default Browser App and choose Oriel. \
        Until then, Oriel still opens http/https links that are shared into the app.
        """
        #endif
    }

    func refreshStatus() {
        lastError = nil
        #if os(macOS)
        isDefaultForHTTP = Self.isOrielDefault(forScheme: "http")
        isDefaultForHTTPS = Self.isOrielDefault(forScheme: "https")
        if isDefaultBrowser {
            lastStatusMessage = "Oriel is your default browser."
        } else if isDefaultForHTTP || isDefaultForHTTPS {
            lastStatusMessage = "Oriel is partially set as default — finish for both http and https."
        } else {
            lastStatusMessage = "Oriel is not the default browser yet."
        }
        #else
        // iOS does not expose which app is the default browser to third parties.
        isDefaultForHTTP = false
        isDefaultForHTTPS = false
        lastStatusMessage = "Choose Oriel in Settings → Apps → Default Browser App when available."
        #endif
    }

    /// Makes Oriel the default handler (macOS) or opens the Default Apps settings pane (iOS).
    func promoteToDefaultBrowser() {
        lastError = nil
        #if os(macOS)
        let bundleURL = Bundle.main.bundleURL
        Task {
            do {
                try await NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "http")
                try await NSWorkspace.shared.setDefaultApplication(at: bundleURL, toOpenURLsWithScheme: "https")
                refreshStatus()
                if isDefaultBrowser {
                    lastStatusMessage = "Oriel is now your default browser."
                } else {
                    lastStatusMessage = "Requested default browser change. Confirm in System Settings if prompted."
                }
            } catch {
                lastError = error.localizedDescription
                lastStatusMessage = nil
                refreshStatus()
            }
        }
        #else
        openDefaultBrowserSettings()
        #endif
    }

    func openDefaultBrowserSettings() {
        #if os(iOS)
        var opened = false
        if #available(iOS 18.3, *) {
            if let url = URL(string: UIApplication.openDefaultApplicationsSettingsURLString),
               UIApplication.shared.canOpenURL(url) {
                UIApplication.shared.open(url)
                opened = true
            }
        }
        if !opened, let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
            opened = true
        }
        if opened {
            lastStatusMessage = "Opened Settings. Look for Default Browser App."
        } else {
            lastError = "Could not open Settings."
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.general") {
            NSWorkspace.shared.open(url)
            lastStatusMessage = "Opened System Settings. You can also use the button above."
        }
        #endif
    }

    #if os(macOS)
    private static func isOrielDefault(forScheme scheme: String) -> Bool {
        guard let probe = URL(string: "\(scheme)://openoriel.com") else { return false }
        guard let handler = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return false }
        return handler.resolvingSymlinksInPath() == Bundle.main.bundleURL.resolvingSymlinksInPath()
    }
    #endif
}
