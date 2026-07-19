import Foundation

#if os(macOS)
import AppKit
#endif

/// Optional bridge for a future Chromium/CEF host on Mac.
/// Today Oriel always paints with WebKit; this type records intent and can open system Chrome.
@MainActor
enum ChromiumEngineBridge {
    /// True when a native Chromium framework is present (future builds).
    static var isNativeFrameworkLinked: Bool {
        RenderingEnginePolicy.chromiumNativeStatus == .available
    }

    /// Open the URL in Google Chrome or Chromium if installed (Mac escape hatch).
    @discardableResult
    static func openInSystemChromium(_ url: URL) -> Bool {
        #if os(macOS)
        let candidates = [
            "com.google.Chrome",
            "com.google.Chrome.beta",
            "com.google.Chrome.dev",
            "org.chromium.Chromium",
            "company.thebrowser.Browser" // Arc — Chromium-based
        ]
        let workspace = NSWorkspace.shared
        for bundleID in candidates {
            if let appURL = workspace.urlForApplication(withBundleIdentifier: bundleID) {
                let config = NSWorkspace.OpenConfiguration()
                workspace.open([url], withApplicationAt: appURL, configuration: config) { _, _ in }
                return true
            }
        }
        return false
        #else
        return false
        #endif
    }

    static var systemChromiumInstalled: Bool {
        #if os(macOS)
        let ids = ["com.google.Chrome", "org.chromium.Chromium", "com.google.Chrome.beta"]
        return ids.contains { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0) != nil }
        #else
        return false
        #endif
    }
}
