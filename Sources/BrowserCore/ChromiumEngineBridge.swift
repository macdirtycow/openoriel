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

    private static let candidateBundleIDs = [
        "com.google.Chrome",
        "com.google.Chrome.beta",
        "com.google.Chrome.dev",
        "com.google.Chrome.canary",
        "org.chromium.Chromium",
        "company.thebrowser.Browser", // Arc
        "com.brave.Browser",
        "com.microsoft.edgemac"
    ]

    /// Open the URL in Google Chrome, Chromium, Arc, Brave, or Edge if installed (Mac escape hatch).
    @discardableResult
    static func openInSystemChromium(_ url: URL) -> Bool {
        #if os(macOS)
        let workspace = NSWorkspace.shared
        for bundleID in candidateBundleIDs {
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
        return preferredSystemChromiumBundleID != nil
        #else
        return false
        #endif
    }

    static var preferredSystemChromiumBundleID: String? {
        #if os(macOS)
        for bundleID in candidateBundleIDs {
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                return bundleID
            }
        }
        return nil
        #else
        return nil
        #endif
    }

    static var preferredSystemChromiumName: String? {
        guard let id = preferredSystemChromiumBundleID else { return nil }
        switch id {
        case "com.google.Chrome", "com.google.Chrome.beta", "com.google.Chrome.dev", "com.google.Chrome.canary":
            return "Google Chrome"
        case "org.chromium.Chromium":
            return "Chromium"
        case "company.thebrowser.Browser":
            return "Arc"
        case "com.brave.Browser":
            return "Brave"
        case "com.microsoft.edgemac":
            return "Microsoft Edge"
        default:
            return "Chromium browser"
        }
    }
}
