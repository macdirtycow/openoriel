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

    private var hasClassicMarkAsset: Bool {
        #if os(iOS)
        return UIImage(named: "OrielMark") != nil
        #elseif os(macOS)
        return NSImage(named: "OrielMark") != nil || NSApplication.shared.applicationIconImage != nil
        #else
        return false
        #endif
    }

    private var hasPulseMarkAsset: Bool {
        #if os(iOS)
        return UIImage(named: "OrielMarkPulse") != nil
        #elseif os(macOS)
        return NSImage(named: "OrielMarkPulse") != nil
        #else
        return false
        #endif
    }

    var body: some View {
        Group {
            if isPulse {
                if hasPulseMarkAsset {
                    Image("OrielMarkPulse")
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    drawnPulseMark
                }
            } else if hasClassicMarkAsset {
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

    /// Fallback Pulse mark — ink studio + one vermillion pane (matches OrielMarkPulse asset).
    private var drawnPulseMark: some View {
        let ink = EditionBranding.pulseNavy
        let well = Color(red: 0.09, green: 0.10, blue: 0.13)
        let pane = Color(red: 0.14, green: 0.16, blue: 0.20)
        let steel = EditionBranding.pulseSteel
        let signal = EditionBranding.pulseAccent
        let signalSoft = EditionBranding.pulseAccentSoft
        let bar = max(1.4, size * 0.038)
        let inset = size * 0.24
        let gap = size * 0.035

        return ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.055, green: 0.06, blue: 0.08), ink],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(well)
                .padding(size * 0.09)
            // Four panes
            VStack(spacing: gap) {
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                        .fill(pane)
                    RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [signalSoft, signal],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                HStack(spacing: gap) {
                    RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                        .fill(pane)
                    RoundedRectangle(cornerRadius: size * 0.055, style: .continuous)
                        .fill(pane)
                }
            }
            .padding(inset)
            // Mullions
            RoundedRectangle(cornerRadius: bar / 2, style: .continuous)
                .fill(steel)
                .frame(width: bar)
                .padding(.vertical, inset)
            RoundedRectangle(cornerRadius: bar / 2, style: .continuous)
                .fill(steel)
                .frame(height: bar)
                .padding(.horizontal, inset)
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .strokeBorder(steel.opacity(0.45), lineWidth: max(1, size * 0.02))
                .padding(max(1, size * 0.018))
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
