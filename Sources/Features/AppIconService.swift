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

    func applyForEdition(_ edition: BrowserEdition) async {
        await setPulseIcon(edition.isPulse)
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
                Task { @MainActor in
                    if let error {
                        self.lastError = error.localizedDescription
                    }
                    cont.resume()
                }
            }
        }
        #elseif os(macOS)
        // applicationIconImage bypasses the system squircle mask — always mask ourselves
        // so the Dock icon stays inside the same kaders as every other Mac app.
        if enabled {
            if let image = Self.bestPulseDockImage() {
                // Runtime Dock overrides skip the system mask — clip to a squircle ourselves.
                NSApplication.shared.applicationIconImage = Self.dockMasked(image)
            } else {
                lastError = "Pulse Dock icon asset missing."
            }
        } else {
            // Restore bundle AppIcon so macOS applies the real continuous-corner mask.
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
        return NSImage(named: "OrielMarkPulse") ?? NSImage(named: "AppIconPulse")
    }

    /// Clip to a continuous squircle so Dock overrides match system-masked AppIcon assets.
    private static func dockMasked(_ source: NSImage) -> NSImage {
        let pixel = max(128, Int(max(source.size.width, source.size.height).rounded()))
        let size = NSSize(width: pixel, height: pixel)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        NSGraphicsContext.current?.imageInterpolation = .high
        let rect = NSRect(origin: .zero, size: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: size.width * 0.2237, yRadius: size.height * 0.2237)
        path.addClip()
        source.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        image.isTemplate = false
        return image
    }
    #endif
}
