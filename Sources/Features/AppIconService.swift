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
        if enabled, let image = NSImage(named: "AppIconPulse") ?? Self.bundledPulseIcon() {
            NSApplication.shared.applicationIconImage = image
        } else if let primary = NSImage(named: "AppIcon") {
            NSApplication.shared.applicationIconImage = primary
        } else {
            NSApplication.shared.applicationIconImage = nil
        }
        #endif
    }

    #if os(macOS)
    private static func bundledPulseIcon() -> NSImage? {
        if let url = Bundle.main.url(forResource: "AppIconPulse", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
    #endif
}
