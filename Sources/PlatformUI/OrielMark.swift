import SwiftUI

/// Small toolbar-safe Oriel monogram (not the full app icon — that looks wrong at 20pt).
struct OrielMark: View {
    var size: CGFloat = 22
    var showsWordmark: Bool = false

    var body: some View {
        HStack(spacing: 7) {
            Text("O")
                .font(.system(size: size * 0.58, weight: .bold, design: .serif))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.18, green: 0.32, blue: 0.34),
                            Color(red: 0.12, green: 0.22, blue: 0.24)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                )
                .accessibilityHidden(true)

            if showsWordmark {
                Text(BrowserConstants.productName)
                    .font(.system(size: max(13, size * 0.62), weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BrowserConstants.productName)
    }
}
