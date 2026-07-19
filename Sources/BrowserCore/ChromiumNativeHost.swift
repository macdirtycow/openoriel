import Foundation
#if os(macOS)
import AppKit
#endif

/// Mac Oriel Engine runtime (Blink).
///
/// - **Bundled CEF**: framework in the app + binary built with `ORIEL_HAS_CEF` → in-tab Blink.
/// - **Managed Chromium**: otherwise Oriel Engine opens a real Chromium process (Chrome/Brave/Edge/Arc).
@MainActor
enum ChromiumNativeHost {
    /// True when a CEF/Chromium framework is present on disk (Application Support or app bundle).
    static var isEmbeddedFrameworkAvailable: Bool {
        OrielCEFSupport.isFrameworkOnDisk
    }

    /// True when in-tab Blink hosting can run.
    static var isEmbeddedHostingReady: Bool {
        OrielCEFSupport.isReady
    }

    static var embeddedFrameworkURL: URL? {
        OrielCEFSupport.frameworkURL
    }

    static var statusSummary: String {
        #if os(iOS)
        return ChromiumNativeStatus.unavailableOnIOS.userMessage
        #else
        if OrielCEFSupport.isReady {
            return OrielCEFSupport.statusSummary
        }
        if OrielCEFSupport.isFrameworkOnDisk {
            return OrielCEFSupport.statusSummary
        }
        if ChromiumEngineBridge.systemChromiumInstalled {
            let name = ChromiumEngineBridge.preferredSystemChromiumName ?? "Chrome"
            return "Oriel Engine CEF is not bundled in this build. Using managed \(name) app-windows (real Chromium process). Ship via Scripts/make-macos-dmg.sh (bundles Engine by default)."
        }
        return "Install Chrome/Brave/Edge/Arc for managed Oriel Engine windows, or build a Mac DMG with Oriel Engine bundled."
        #endif
    }

    /// Open a real Chromium process window for this URL (app mode when supported).
    @discardableResult
    static func openManagedNativeWindow(_ url: URL) -> Bool {
        #if os(macOS)
        guard let bundleID = ChromiumEngineBridge.preferredSystemChromiumBundleID,
              let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return ChromiumEngineBridge.openInSystemChromium(url)
        }
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = ["--new-window", "--app=\(url.absoluteString)"]
        NSWorkspace.shared.open(
            [],
            withApplicationAt: appURL,
            configuration: config
        ) { _, error in
            if error != nil {
                Task { @MainActor in
                    _ = ChromiumEngineBridge.openInSystemChromium(url)
                }
            }
        }
        return true
        #else
        return false
        #endif
    }

    /// Prefer managed windows only when in-tab CEF hosting is not ready.
    static var prefersManagedNativeWindows: Bool {
        #if os(macOS)
        return !isEmbeddedHostingReady && ChromiumEngineBridge.systemChromiumInstalled
        #else
        return false
        #endif
    }

    static func clearEmbeddedBrowsingData() {
        #if os(macOS)
        guard isEmbeddedHostingReady else { return }
        // Best-effort: a transient host clears the global CEF cookie store.
        let host = OrielCEFHost(frame: .zero)
        host.clearCookiesAndCache()
        #endif
    }
}
