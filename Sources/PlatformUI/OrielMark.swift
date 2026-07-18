import SwiftUI
#if os(macOS)
import AppKit
#endif

/// Compact Oriel brand mark for chrome (pages + compact windows).
struct OrielMark: View {
    var size: CGFloat = 22
    var showsWordmark: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                .accessibilityHidden(true)

            if showsWordmark {
                Text(BrowserConstants.productName)
                    .font(.system(size: size * 0.72, weight: .semibold, design: .serif))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(BrowserConstants.productName)
    }

    @ViewBuilder
    private var icon: some View {
        #if os(macOS)
        Image(nsImage: NSApplication.shared.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
        #else
        Image(systemName: "square.on.square.dashed")
            .font(.system(size: size * 0.72, weight: .medium))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        #endif
    }
}
