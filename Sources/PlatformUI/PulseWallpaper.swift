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
        case .nebula: "Nebula"
        case .grid: "Circuit grid"
        case .aurora: "Pulse aurora"
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
                    colors: [EditionBranding.pulseMagenta.opacity(0.35), EditionBranding.pulseAccent.opacity(0.12), .clear],
                    center: .topTrailing,
                    startRadius: 20,
                    endRadius: 520
                )
                RadialGradient(
                    colors: [EditionBranding.pulseNavy.opacity(0.55), .clear],
                    center: .bottomLeading,
                    startRadius: 10,
                    endRadius: 480
                )
            }
            .allowsHitTesting(false)
        case .grid:
            Canvas { context, size in
                let step: CGFloat = 28
                var path = Path()
                stride(from: 0, through: size.width, by: step).forEach { x in
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                }
                stride(from: 0, through: size.height, by: step).forEach { y in
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(path, with: .color(EditionBranding.pulseAccent.opacity(0.12)), lineWidth: 1)
            }
            .allowsHitTesting(false)
        case .aurora:
            LinearGradient(
                colors: [
                    EditionBranding.pulseAccent.opacity(0.28),
                    EditionBranding.pulseMagenta.opacity(0.18),
                    accent.opacity(0.08),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .allowsHitTesting(false)
        }
    }
}
