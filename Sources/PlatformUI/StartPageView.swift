import SwiftUI

struct StartPageView: View {
    @Environment(AppEnvironment.self) private var environment
    let tab: BrowserTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                if !environment.bookmarks.favorites.isEmpty {
                    section(title: "Favorites") {
                        tileGrid(items: environment.bookmarks.favorites.map {
                            ($0.title, $0.urlString)
                        })
                    }
                }

                if !environment.history.recentSites.isEmpty {
                    section(title: "Recent") {
                        tileGrid(items: environment.history.recentSites.map {
                            ($0.title, $0.urlString)
                        })
                    }
                }

                section(title: "Suggested") {
                    tileGrid(items: [
                        ("openoriel.com", BrowserConstants.productWebsiteURL.absoluteString),
                        ("DuckDuckGo", "https://duckduckgo.com"),
                        ("Wikipedia", "https://wikipedia.org"),
                        ("Apple Developer", "https://developer.apple.com")
                    ])
                }

                HStack(spacing: 12) {
                    Button {
                        tab.openProductSite()
                    } label: {
                        Label(BrowserConstants.productWebsiteHost, systemImage: "globe")
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        tab.openPublisherSite()
                    } label: {
                        Label("Made by \(BrowserConstants.publisherName)", systemImage: "building.2")
                    }
                    .buttonStyle(.bordered)
                }
                .font(.subheadline.weight(.semibold))

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background {
            LinearGradient(
                colors: [Color.accentColor.opacity(0.12), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BrowserConstants.productName)
                .font(.largeTitle.weight(.bold))
                .tracking(-0.5)

            Text("A calm, private-minded browser.")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(BrowserConstants.productWebsiteHost)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OrielTheme.brandPrimary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 24)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content()
        }
    }

    private func tileGrid(items: [(String, String)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(items, id: \.1) { item in
                Button {
                    if let url = URL(string: item.1) {
                        tab.load(url)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Image(systemName: "globe")
                            .font(.title2)
                        Text(item.0)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(item.1.replacingOccurrences(of: "https://", with: ""))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
