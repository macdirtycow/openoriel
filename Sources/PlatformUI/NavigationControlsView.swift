import SwiftUI

/// Back / forward / reload / home controls with clear disabled states and hit targets.
struct NavigationControlsView: View {
    @Bindable var tab: BrowserTab
    /// Narrow chrome: only back/forward so the address bar stays centered.
    var style: Style = .full

    enum Style {
        case full
        case compact
    }

    private var isStartPage: Bool {
        URLParser.isStartPage(tab.navigation.url)
    }

    var body: some View {
        HStack(spacing: style == .compact ? 0 : 4) {
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
        }
    }

    private var buttonSize: CGFloat {
        style == .compact ? 30 : OrielLayout.navButtonSize
    }

    private func navButton(
        systemName: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.body.weight(.semibold))
                .frame(width: buttonSize, height: buttonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
        .accessibilityHint(enabled ? "" : "Unavailable")
        .help(label)
    }
}
