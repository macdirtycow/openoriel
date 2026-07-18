import SwiftUI

/// Back / forward / reload / home, plus the Oriel Shields app-icon control (Brave-style).
struct NavigationControlsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Bindable var tab: BrowserTab
    /// Narrow chrome: back/forward + Oriel Shields only.
    var style: Style = .full

    enum Style {
        case full
        case compact
    }

    private var isStartPage: Bool {
        URLParser.isStartPage(tab.navigation.url)
    }

    private var buttonSize: CGFloat {
        style == .compact ? 28 : 32
    }

    private var markSize: CGFloat {
        style == .compact ? 18 : 20
    }

    var body: some View {
        HStack(spacing: style == .compact ? 0 : 2) {
            navButton(
                systemName: "chevron.backward",
                label: "Back",
                enabled: tab.navigation.canGoBack
            ) {
                tab.goBack()
            }

            navButton(
                systemName: "chevron.forward",
                label: "Forward",
                enabled: tab.navigation.canGoForward
            ) {
                tab.goForward()
            }

            if style == .full {
                navButton(
                    systemName: tab.navigation.isLoading ? "xmark" : "arrow.clockwise",
                    label: tab.navigation.isLoading ? "Stop" : "Reload",
                    enabled: !isStartPage || tab.navigation.isLoading
                ) {
                    if tab.navigation.isLoading {
                        tab.stopLoading()
                    } else {
                        tab.reload()
                    }
                }

                navButton(
                    systemName: "house",
                    label: "Home",
                    enabled: !isStartPage
                ) {
                    tab.goHome()
                }
            }

            // App-icon Shields toggle — sits with nav, next to Home (like Brave’s lion).
            OrielShieldButton(size: markSize)
                .padding(.leading, style == .compact ? 2 : 4)
        }
    }

    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: style == .compact ? 14 : 15, weight: .semibold))
                .foregroundStyle(enabled ? Color.primary.opacity(0.85) : Color.secondary.opacity(0.35))
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(OrielNavGlyphButtonStyle())
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityHint(enabled ? "" : "Unavailable")
        .help(label)
    }
}

/// Quiet press feedback for toolbar glyphs — no filled chips or borders.
private struct OrielNavGlyphButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.45 : 1)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
