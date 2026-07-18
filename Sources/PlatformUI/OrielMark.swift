import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Toolbar Oriel mark from the real app icon (scaled cleanly — not the huge dock icon stretched).
struct OrielMark: View {
    var size: CGFloat = 22

    var body: some View {
        Group {
            #if os(macOS)
            if let icon = Self.macToolbarIcon(pointSize: size) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                fallbackMonogram
            }
            #else
            if let icon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon.appiconset") {
                Image(uiImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
            } else {
                fallbackMonogram
            }
            #endif
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }

    private var fallbackMonogram: some View {
        Text("O")
            .font(.system(size: size * 0.55, weight: .bold, design: .serif))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                Color(red: 0.14, green: 0.26, blue: 0.28),
                in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            )
    }

    #if os(macOS)
    private static func macToolbarIcon(pointSize: CGFloat) -> NSImage? {
        guard let source = NSApplication.shared.applicationIconImage else { return nil }
        guard source.size.width > 0, source.size.height > 0 else { return nil }
        let pixel = max(16, Int((pointSize * 2).rounded()))
        let targetSize = NSSize(width: pixel, height: pixel)
        let image = NSImage(size: targetSize)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        source.draw(
            in: NSRect(origin: .zero, size: targetSize),
            from: NSRect(origin: .zero, size: source.size),
            operation: .copy,
            fraction: 1
        )
        image.unlockFocus()
        image.isTemplate = false
        return image
    }
    #endif
}

/// Brave-style Oriel Shields control: app icon, default on, click to toggle, context menu for details.
struct OrielShieldButton: View {
    @Environment(AppEnvironment.self) private var environment
    var size: CGFloat = 22

    private var shieldsOn: Bool {
        environment.privacy.contentBlockingEnabled
    }

    var body: some View {
        Button {
            toggleShields()
        } label: {
            ZStack {
                OrielMark(size: size)
                    .opacity(shieldsOn ? 1 : 0.4)
                if !shieldsOn {
                    Image(systemName: "line.diagonal")
                        .font(.system(size: size * 0.55, weight: .bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: size + 8, height: size + 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .help(shieldsOn ? "Oriel Shields on — click to turn off" : "Oriel Shields off — click to turn on")
        .accessibilityLabel("Oriel Shields")
        .accessibilityValue(shieldsOn ? "On" : "Off")
        .accessibilityHint("Toggles tracker blocking and HTTPS upgrades")
        .contextMenu {
            Button(shieldsOn ? "Turn Shields Off" : "Turn Shields On") {
                toggleShields()
            }
            Button("Shield settings…") {
                environment.showPrivacyShield = true
            }
        }
    }

    private func toggleShields() {
        let next = !environment.privacy.contentBlockingEnabled
        environment.privacy.contentBlockingEnabled = next
        environment.privacy.httpsUpgradeEnabled = next
    }
}
