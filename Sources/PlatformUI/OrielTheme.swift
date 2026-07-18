import SwiftUI
#if os(iOS)
import UIKit
#endif

/// User-selectable accent colors for chrome, start page, and tint.
enum BrowserAccentTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case teal
    case ocean
    case forest
    case dusk
    case rose
    case slate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .teal: "Teal"
        case .ocean: "Ocean"
        case .forest: "Forest"
        case .dusk: "Dusk"
        case .rose: "Rose"
        case .slate: "Slate"
        }
    }

    var color: Color {
        switch self {
        case .teal: Color(red: 0.18, green: 0.38, blue: 0.42)
        case .ocean: Color(red: 0.14, green: 0.42, blue: 0.62)
        case .forest: Color(red: 0.20, green: 0.42, blue: 0.30)
        case .dusk: Color(red: 0.36, green: 0.28, blue: 0.55)
        case .rose: Color(red: 0.55, green: 0.28, blue: 0.36)
        case .slate: Color(red: 0.30, green: 0.34, blue: 0.40)
        }
    }

    var softColor: Color {
        switch self {
        case .teal: Color(red: 0.52, green: 0.72, blue: 0.78)
        case .ocean: Color(red: 0.45, green: 0.70, blue: 0.88)
        case .forest: Color(red: 0.55, green: 0.78, blue: 0.62)
        case .dusk: Color(red: 0.72, green: 0.62, blue: 0.90)
        case .rose: Color(red: 0.90, green: 0.62, blue: 0.70)
        case .slate: Color(red: 0.70, green: 0.74, blue: 0.80)
        }
    }

    /// Accent that stays readable on the current start-page scheme.
    func readable(on scheme: ColorScheme) -> Color {
        scheme == .dark ? softColor : color
    }
}

/// Start-page / chrome background treatments.
enum BrowserBackgroundTheme: String, CaseIterable, Identifiable, Codable, Sendable {
    case soft
    case paper
    case mist
    case sand
    case aurora
    case midnight

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .soft: "Soft"
        case .paper: "Paper"
        case .mist: "Mist"
        case .sand: "Sand"
        case .aurora: "Aurora"
        case .midnight: "Midnight"
        }
    }

    /// Backgrounds that lock light/dark so text contrast stays correct.
    /// Soft is warm cream (matches Settings preview) — without this, Soft + Dark
    /// looks like a plain system gray and feels “broken” on device.
    var forcedColorScheme: ColorScheme? {
        switch self {
        case .midnight: .dark
        case .soft, .paper, .sand: .light
        case .mist, .aurora: nil
        }
    }

    func resolvedColorScheme(system: ColorScheme) -> ColorScheme {
        forcedColorScheme ?? system
    }

    var isVisuallyDark: Bool {
        forcedColorScheme == .dark
    }
}

enum OrielTheme {
    static let chromePadding: CGFloat = 10
    static let controlRadius: CGFloat = 12
    static let searchFieldRadius: CGFloat = 16
    static let searchFieldHeight: CGFloat = 54
    static let sectionRadius: CGFloat = 16
    static let hairlineOpacity: Double = 0.10
    static let chromeButtonRadius: CGFloat = 10

    static let brandTeal = BrowserAccentTheme.teal.color
    static let brandTealSoft = BrowserAccentTheme.teal.softColor

    static func brandPrimary(accent: BrowserAccentTheme = .teal) -> Color {
        // Always use the theme RGB (not the asset) so Settings accent picks update tint live.
        accent.color
    }

    /// Soft chrome wash so iOS/iPad toolbars pick up background themes, not only the start page.
    static func chromeWash(
        accent: BrowserAccentTheme,
        background: BrowserBackgroundTheme,
        scheme: ColorScheme
    ) -> some View {
        let pageScheme = background.resolvedColorScheme(system: scheme)
        return ZStack {
            baseFill(for: background, scheme: pageScheme).opacity(0.92)
            Group {
                bloom(accent: accent, background: background, scheme: pageScheme)
            }
            .opacity(0.55)
        }
    }

    @ViewBuilder
    static func startPageBackground(
        accent: BrowserAccentTheme,
        background: BrowserBackgroundTheme,
        scheme: ColorScheme
    ) -> some View {
        let pageScheme = background.resolvedColorScheme(system: scheme)
        ZStack {
            baseFill(for: background, scheme: pageScheme)
            bloom(accent: accent, background: background, scheme: pageScheme)
            LinearGradient(
                colors: veilColors(scheme: pageScheme),
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    static var startPageBackground: some View {
        startPageBackground(accent: .teal, background: .soft, scheme: .light)
    }

    static var startPageBackgroundDark: some View {
        startPageBackground(accent: .teal, background: .midnight, scheme: .dark)
    }

    static func surfaceFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.82)
    }

    /// Slightly stronger fill for interactive panels (search, shields, tiles).
    static func elevatedFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.12) : Color.white.opacity(0.90)
    }

    static func hairline(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.16) : Color.black.opacity(0.08)
    }

    static func softShadow(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.black.opacity(0.35) : Color.black.opacity(0.06)
    }

    private static func baseFill(for background: BrowserBackgroundTheme, scheme: ColorScheme) -> Color {
        switch background {
        case .soft:
            // Warm parchment — Soft always runs light via forcedColorScheme.
            return Color(red: 0.965, green: 0.948, blue: 0.922)
        case .paper:
            return Color(red: 0.985, green: 0.975, blue: 0.955)
        case .mist:
            return scheme == .dark
                ? Color(red: 0.09, green: 0.11, blue: 0.14)
                : Color(red: 0.93, green: 0.95, blue: 0.97)
        case .sand:
            return Color(red: 0.96, green: 0.93, blue: 0.86)
        case .aurora:
            return scheme == .dark
                ? Color(red: 0.08, green: 0.10, blue: 0.14)
                : Color(red: 0.94, green: 0.95, blue: 0.98)
        case .midnight:
            return Color(red: 0.07, green: 0.08, blue: 0.10)
        }
    }

    @ViewBuilder
    private static func bloom(
        accent: BrowserAccentTheme,
        background: BrowserBackgroundTheme,
        scheme: ColorScheme
    ) -> some View {
        let soft = accent.softColor
        let strong = accent.color
        switch background {
        case .soft:
            RadialGradient(
                colors: [soft.opacity(0.22), Color.clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 460
            )
            RadialGradient(
                colors: [strong.opacity(0.08), Color.clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 380
            )
        case .aurora:
            RadialGradient(
                colors: [soft.opacity(scheme == .dark ? 0.35 : 0.22), Color.clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 380
            )
            RadialGradient(
                colors: [strong.opacity(scheme == .dark ? 0.22 : 0.12), Color.clear],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        case .midnight:
            RadialGradient(
                colors: [strong.opacity(0.32), Color.clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 400
            )
        default:
            RadialGradient(
                colors: [
                    soft.opacity(scheme == .dark ? 0.28 : 0.14),
                    Color.clear
                ],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
    }

    private static func veilColors(scheme: ColorScheme) -> [Color] {
        if scheme == .dark {
            return [Color.white.opacity(0.05), Color.clear]
        }
        return [Color.black.opacity(0.025), Color.clear, Color.black.opacity(0.03)]
    }
}

/// Filled chrome control for trailing toolbar actions (not the left nav glyphs).
struct OrielChromeButtonStyle: ButtonStyle {
    var isEnabled: Bool = true
    var isEmphasized: Bool = false
    var accent: Color = OrielTheme.brandTeal
    var size: CGFloat = OrielLayout.navButtonSize
    var expandsHorizontally: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .frame(
                minWidth: size,
                idealWidth: expandsHorizontally ? nil : size,
                maxWidth: expandsHorizontally ? .infinity : size,
                minHeight: size,
                maxHeight: size
            )
            .padding(.horizontal, expandsHorizontally ? 8 : 0)
            .foregroundStyle(
                isEnabled
                    ? (isEmphasized ? accent : Color.primary.opacity(0.9))
                    : Color.secondary.opacity(0.45)
            )
            .background(
                RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
                    .fill(fillColor(pressed: configuration.isPressed))
            )
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
                    .strokeBorder(
                        isEmphasized && isEnabled
                            ? accent.opacity(0.35)
                            : Color.primary.opacity(configuration.isPressed ? 0.14 : 0.08),
                        lineWidth: 1
                    )
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.94 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .contentShape(RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous))
            .opacity(isEnabled ? 1 : 0.7)
            .fixedSize(horizontal: expandsHorizontally, vertical: true)
    }

    private func fillColor(pressed: Bool) -> Color {
        if isEmphasized && isEnabled {
            return accent.opacity(pressed ? 0.28 : 0.16)
        }
        return Color.primary.opacity(pressed ? 0.12 : 0.06)
    }
}

// MARK: - Root theming

extension View {
    /// Applies appearance + accent tint and keeps UIKit windows in sync on iOS/iPadOS.
    func orielTheming(settings: BrowserSettings) -> some View {
        modifier(OrielThemingModifier(settings: settings))
    }
}

private struct OrielThemingModifier: ViewModifier {
    @Bindable var settings: BrowserSettings

    func body(content: Content) -> some View {
        content
            .preferredColorScheme(resolvedPreferredScheme)
            .tint(settings.brandColor)
            .onAppear { syncPlatformChrome() }
            .onChange(of: settings.appearance) { _, _ in syncPlatformChrome() }
            .onChange(of: settings.accentTheme) { _, _ in syncPlatformChrome() }
            .onChange(of: settings.backgroundTheme) { _, _ in syncPlatformChrome() }
    }

    /// Background theme locks (Soft/Paper/Midnight) beat Appearance so previews match the page.
    private var resolvedPreferredScheme: ColorScheme? {
        if let forced = settings.backgroundTheme.forcedColorScheme {
            return forced
        }
        return settings.appearance.colorScheme
    }

    private func syncPlatformChrome() {
        #if os(iOS)
        let style: UIUserInterfaceStyle
        if let scheme = resolvedPreferredScheme {
            style = scheme == .dark ? .dark : .light
        } else {
            style = .unspecified
        }
        let tint = UIColor(settings.brandColor)
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.overrideUserInterfaceStyle = style
                window.tintColor = tint
            }
        }
        #endif
    }
}
