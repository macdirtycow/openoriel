import SwiftUI

struct StartPageView: View {
    @Environment(AppEnvironment.self) private var environment
    let tab: BrowserTab

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header

                searchEngineChooser

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

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        productButton
                        publisherButton
                    }
                    VStack(spacing: 10) {
                        productButton
                        publisherButton
                    }
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

    private var searchEngineChooser: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Search with")
                    .font(.headline)
                Spacer()
                Button("Settings") {
                    environment.showSettings = true
                }
                .font(.subheadline.weight(.semibold))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SearchEngine.allCases) { engine in
                        let selected = environment.settings.searchEngine == engine
                        Button {
                            environment.setSearchEngine(engine)
                            tab.searchEngine = engine
                        } label: {
                            Label(engine.displayName, systemImage: engine.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    selected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.12),
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selected ? [.isSelected] : [])
                        .accessibilityLabel("\(engine.displayName) search engine")
                    }
                }
            }
        }
    }

    private var productButton: some View {
        Button {
            tab.openProductSite()
        } label: {
            Label(BrowserConstants.productWebsiteHost, systemImage: "globe")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint("Opens the official Oriel website")
    }

    private var publisherButton: some View {
        Button {
            tab.openPublisherSite()
        } label: {
            Label("Made by \(BrowserConstants.publisherName)", systemImage: "building.2")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .accessibilityHint("Opens the publisher website")
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
