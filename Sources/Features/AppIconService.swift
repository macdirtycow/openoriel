import Foundation
import Observation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

/// Switches the home-screen / Dock icon between Classic and Pulse.
@MainActor
@Observable
final class AppIconService {
    private(set) var lastError: String?
    private(set) var supportsAlternateIcons: Bool = false

    /// Asset catalog alternate icon name (`AppIconPulse`), or nil for primary.
    var preferredIconName: String? {
        didSet {
            UserDefaults.standard.set(preferredIconName ?? "", forKey: "oriel.alternateIconName")
        }
    }

    init() {
        let stored = UserDefaults.standard.string(forKey: "oriel.alternateIconName")
        preferredIconName = (stored?.isEmpty == false) ? stored : nil
        #if os(iOS)
        supportsAlternateIcons = UIApplication.shared.supportsAlternateIcons
        #elseif os(macOS)
        supportsAlternateIcons = true
        #endif
    }

    var isPulseIconActive: Bool {
        preferredIconName == "AppIconPulse"
    }

    func applyForEdition(_ edition: BrowserEdition) {
        Task { await setPulseIcon(edition.isPulse) }
    }

    func setPulseIcon(_ enabled: Bool) async {
        lastError = nil
        let name: String? = enabled ? "AppIconPulse" : nil
        preferredIconName = name
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            supportsAlternateIcons = false
            lastError = "Alternate icons aren’t available on this device."
            return
        }
        supportsAlternateIcons = true
        guard UIApplication.shared.alternateIconName != name else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            UIApplication.shared.setAlternateIconName(name) { error in
                if let error {
                    self.lastError = error.localizedDescription
                }
                cont.resume()
            }
        }
        #elseif os(macOS)
        if enabled {
            if let image = Self.bestPulseDockImage() {
                NSApplication.shared.applicationIconImage = image
            } else {
                lastError = "Pulse Dock icon asset missing."
            }
        } else if let primary = Self.bestClassicDockImage() {
            NSApplication.shared.applicationIconImage = primary
        } else {
            // Relinquish override so the bundle AppIcon returns.
            NSApplication.shared.applicationIconImage = nil
        }
        #endif
    }

    #if os(macOS)
    /// Prefer large catalog / imageset assets — never the tiny AlternateIcons IPA sidecars.
    private static func bestPulseDockImage() -> NSImage? {
        let names = ["AppIconPulse", "OrielMarkPulse"]
        for name in names {
            if let image = NSImage(named: name), image.size.width >= 128 {
                return image
            }
        }
        for name in ["mac512@2x", "mac512", "Icon-1024", "AppIconPulse"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url),
               image.size.width >= 64 {
                return image
            }
        }
        // Last resort: any named Pulse mark (even if small).
        return NSImage(named: "OrielMarkPulse") ?? NSImage(named: "AppIconPulse")
    }

    private static func bestClassicDockImage() -> NSImage? {
        if let image = NSImage(named: "AppIcon"), image.size.width >= 128 {
            return image
        }
        if let image = NSImage(named: "OrielMark"), image.size.width >= 64 {
            return image
        }
        for name in ["mac512@2x", "mac512", "AppIcon-1024", "AppIcon"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url) {
                return image
            }
        }
        return NSImage(named: "AppIcon") ?? NSImage(named: "OrielMark")
    }
    #endif
}
