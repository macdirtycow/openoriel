import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// Toolbar / chrome Oriel mark — branded asset (AppIcon cannot be loaded by name on iOS).
struct OrielMark: View {
    @Environment(AppEnvironment.self) private var environment
    var size: CGFloat = 22
    /// When set, overrides the active edition (previews / onboarding).
    var forcePulse: Bool? = nil

    private var isPulse: Bool {
        forcePulse ?? environment.settings.edition.isPulse
    }

    private var hasMarkAsset: Bool {
        guard !isPulse else { return false }
        #if os(iOS)
        return UIImage(named: "OrielMark") != nil
        #elseif os(macOS)
        return NSImage(named: "OrielMark") != nil || NSApplication.shared.applicationIconImage != nil
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if isPulse {
                drawnPulseMark
            } else if hasMarkAsset {
                #if os(macOS)
                if NSImage(named: "OrielMark") != nil {
                    Image("OrielMark")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else if let icon = Self.macToolbarIcon(pointSize: size) {
                    Image(nsImage: icon)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    drawnMark
                }
                #else
                Image("OrielMark")
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                #endif
            } else {
                drawnMark
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Matches `site/assets/oriel-mark.svg` / AppIcon window panes — never a letter “O”.
    private var drawnMark: some View {
        let navy = Color(red: 0.10, green: 0.16, blue: 0.28)
        let mid = Color(red: 0.35, green: 0.48, blue: 0.68)
        let pane = Color(red: 0.86, green: 0.91, blue: 0.96)

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(navy)
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .fill(mid)
                .padding(size * 0.10)
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(pane)
                .padding(size * 0.28)
            Rectangle()
                .fill(navy)
                .frame(width: max(1.5, size * 0.06))
                .padding(.vertical, size * 0.28)
            Rectangle()
                .fill(navy)
                .frame(height: max(1.5, size * 0.06))
                .padding(.horizontal, size * 0.28)
        }
    }

    /// Pulse mark — same window panes, cyan / magenta energy on deep navy.
    private var drawnPulseMark: some View {
        let navy = EditionBranding.pulseNavy
        let cyan = EditionBranding.pulseAccent
        let magenta = EditionBranding.pulseMagenta
        let pane = Color(red: 0.12, green: 0.18, blue: 0.28)

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [navy, Color(red: 0.10, green: 0.12, blue: 0.22)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.18, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [cyan, magenta], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: max(1.2, size * 0.05)
                )
                .padding(size * 0.08)
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(pane)
                .padding(size * 0.28)
            Rectangle()
                .fill(cyan.opacity(0.85))
                .frame(width: max(1.5, size * 0.06))
                .padding(.vertical, size * 0.28)
            Rectangle()
                .fill(magenta.opacity(0.75))
                .frame(height: max(1.5, size * 0.06))
                .padding(.horizontal, size * 0.28)
        }
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

    private var productLabel: String {
        EditionBranding.productName(for: environment.settings.edition)
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
        .help(shieldsOn ? "\(productLabel) Shields on. Click to turn off." : "\(productLabel) Shields off. Click to turn on.")
        .accessibilityLabel("\(productLabel) Shields")
        .accessibilityValue(shieldsOn ? "On" : "Off")
        .accessibilityHint("Toggles tracker blocking and HTTPS upgrades")
        .contextMenu {
            Button(shieldsOn ? "Turn Shields Off" : "Turn Shields On") {
                toggleShields()
            }
            Button("Shield settings…") {
                environment.showPrivacyShield = true
            }
            if environment.settings.edition.isPulse {
                Button("Pulse performance…") {
                    environment.showPulsePerformance = true
                }
            }
        }
    }

    private func toggleShields() {
        let next = !environment.privacy.contentBlockingEnabled
        environment.privacy.contentBlockingEnabled = next
        environment.privacy.httpsUpgradeEnabled = next
    }
}
