import SwiftUI

enum PulseWallpaper: String, CaseIterable, Identifiable, Sendable {
    case off
    case nebula
    case grid
    case aurora

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "Off"
        case .nebula: "Ember wash"
        case .grid: "Studio grid"
        case .aurora: "Signal drift"
        }
    }

    @ViewBuilder
    func background(accent: Color) -> some View {
        switch self {
        case .off:
            Color.clear
        case .nebula:
            ZStack {
                RadialGradient(
                    colors: [
                        EditionBranding.pulseAccent.opacity(0.22),
                        EditionBranding.pulseAccent.opacity(0.06),
                        .clear
                    ],
                    center: UnitPoint(x: 0.82, y: 0.12),
                    startRadius: 8,
                    endRadius: 460
                )
                RadialGradient(
                    colors: [
                        EditionBranding.pulseNavy.opacity(0.7),
                        .clear
                    ],
                    center: .bottomLeading,
                    startRadius: 20,
                    endRadius: 520
                )
            }
            .allowsHitTesting(false)
        case .grid:
            Canvas { context, size in
                let step: CGFloat = 36
                var path = Path()
                stride(from: 0, through: size.width, by: step).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 0, through: size.height, by: step).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(EditionBranding.pulseSteel.opacity(0.10)), lineWidth: 1)
                // Single signal node — not a neon cluster.
                let node = CGRect(x: size.width * 0.72, y: size.height * 0.18, width: 5, height: 5)
                context.fill(Path(ellipseIn: node), with: .color(EditionBranding.pulseAccent.opacity(0.55)))
            }
            .allowsHitTesting(false)
        case .aurora:
            LinearGradient(
                colors: [
                    EditionBranding.pulseAccent.opacity(0.16),
                    EditionBranding.pulseSteel.opacity(0.06),
                    .clear,
                    EditionBranding.pulseNavy.opacity(0.35)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .allowsHitTesting(false)
        }
    }
}
