import SwiftUI

#if os(macOS)
/// Compact Mac chrome chip: which concrete engine Smart resolved, and why.
struct SmartEngineChip: View {
    @Environment(AppEnvironment.self) private var environment
    let tab: BrowserTab

    private var concrete: BrowserEngineKind {
        environment.resolvedEngine(for: tab)
    }

    private var reason: String {
        environment.engineReason(for: tab)
    }

    var body: some View {
        Group {
            if !tab.isShowingStartPage {
                Menu {
                    Text(reason)
                    Divider()
                    Button("Site Passport…") {
                        environment.showSitePassport = true
                    }
                    Button("Engine settings…") {
                        environment.showChromiumFeatures = true
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: concrete.systemImage)
                            .font(.caption2.weight(.semibold))
                        Text(shortLabel)
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.primary.opacity(0.06), in: Capsule(style: .continuous))
                    .overlay {
                        Capsule(style: .continuous)
                            .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                    }
                }
                .menuStyle(.borderlessButton)
                .help(reason)
                .accessibilityLabel("Page engine \(concrete.displayName)")
                .accessibilityHint(reason)
            }
        }
    }

    private var shortLabel: String {
        switch concrete {
        case .smart: "Smart"
        case .webkit: "WebKit"
        case .chromiumCompatibility: "Compatible"
        case .chromiumNative: "Native"
        }
    }
}
#endif
