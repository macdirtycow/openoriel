import SwiftUI

enum OrielTheme {
    static let brandPrimary = Color("AccentColor")
    static let chromePadding: CGFloat = 10
    static let controlRadius: CGFloat = 12
    static let searchFieldRadius: CGFloat = 18
    static let searchFieldHeight: CGFloat = 56

    /// Soft bay-window wash — cool slate into clear, not purple.
    static var startPageBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.38, blue: 0.42).opacity(0.18),
                Color(red: 0.45, green: 0.55, blue: 0.52).opacity(0.08),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
