import SwiftUI

struct FaviconImage: View {
    let pageURL: URL?
    var size: CGFloat = 16

    var body: some View {
        Group {
            if let iconURL = FaviconResolver.iconURL(for: pageURL) {
                AsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    default:
                        Image(systemName: "globe")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                Image(systemName: "globe")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.2, style: .continuous))
        .accessibilityHidden(true)
    }
}
