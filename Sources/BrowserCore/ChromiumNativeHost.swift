import Foundation
#if os(macOS)
import AppKit
#endif

/// Mac Chromium Native runtime.
///
/// - **Embedded CEF**: when `Chromium Embedded Framework` / `OrielChromium.framework`
///   is present beside the app (or in Application Support), Native can host Blink tabs.
/// - **Managed Chromium**: until CEF is linked, Native navigations open a real Chromium
///   process (Chrome/Brave/Edge/Arc) in app-mode — honest Blink, separate process.
@MainActor
enum ChromiumNativeHost {
    private static let supportFrameworkName = "Chromium Embedded Framework.framework"
    private static let bundledNames = [
        "Chromium Embedded Framework",
        "OrielChromium"
    ]

    /// True when a CEF/Chromium framework is loadable for in-process Native tabs.
    static var isEmbeddedFrameworkAvailable: Bool {
        embeddedFrameworkURL != nil
    }

    static var embeddedFrameworkURL: URL? {
        #if os(macOS)
        for name in bundledNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "framework") {
                return url
            }
            if let url = Bundle.main.privateFrameworksURL?
                .appendingPathComponent("\(name).framework", isDirectory: true),
               FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        if let support = try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            let candidate = support
                .appendingPathComponent("Oriel", isDirectory: true)
                .appendingPathComponent("CEF", isDirectory: true)
                .appendingPathComponent(supportFrameworkName, isDirectory: true)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
        #else
        return nil
        #endif
    }

    static var statusSummary: String {
        #if os(iOS)
        return ChromiumNativeStatus.unavailableOnIOS.userMessage
        #else
        if isEmbeddedFrameworkAvailable {
            return "Chromium Native framework found — embedded Blink hosting is available in this Mac build."
        }
        if ChromiumEngineBridge.systemChromiumInstalled {
            let name = ChromiumEngineBridge.preferredSystemChromiumName ?? "Chrome"
            return "No embedded CEF yet. Native mode uses managed \(name) app-windows (real Chromium process). Run Scripts/fetch-cef-macos.sh to install CEF for in-app Native."
        }
        return "Install Chrome/Brave/Edge/Arc for managed Native windows, or run Scripts/fetch-cef-macos.sh to add CEF."
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
        // Prefer app-mode so it feels like a dedicated Native surface.
        if let appMode = URL(string: "\(url.absoluteString)") {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = ["--new-window", "--app=\(appMode.absoluteString)"]
            NSWorkspace.shared.open(
                [],
                withApplicationAt: appURL,
                configuration: config
            ) { _, error in
                if error != nil {
                    // Fallback without --app flags.
                    _ = ChromiumEngineBridge.openInSystemChromium(url)
                }
            }
            return true
        }
        return ChromiumEngineBridge.openInSystemChromium(url)
        #else
        return false
        #endif
    }

    static var prefersManagedNativeWindows: Bool {
        #if os(macOS)
        return !isEmbeddedFrameworkAvailable && ChromiumEngineBridge.systemChromiumInstalled
        #else
        return false
        #endif
    }
}
