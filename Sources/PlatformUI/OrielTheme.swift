import SwiftUI

enum OrielTheme {
    static let brandPrimary = Color("AccentColor")
    static let chromePadding: CGFloat = 10
    static let controlRadius: CGFloat = 12
    static let searchFieldRadius: CGFloat = 14
    static let searchFieldHeight: CGFloat = 52

    /// Quiet paper wash — no neon gradients or glow.
    static var startPageBackground: some View {
        ZStack {
            Color(red: 0.96, green: 0.95, blue: 0.93)
            #if os(macOS)
            // Slight vertical depth only.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.03),
                    Color.clear,
                    Color.black.opacity(0.02)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            #endif
        }
        .ignoresSafeArea()
    }

    static var startPageBackgroundDark: some View {
        ZStack {
            Color(red: 0.11, green: 0.12, blue: 0.13)
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}
