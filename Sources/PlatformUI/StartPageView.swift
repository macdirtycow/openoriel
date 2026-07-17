import SwiftUI

struct StartPageView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: BrowserTab

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var activeEngine: SearchEngine {
        environment.settings.searchEngine
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 36) {
                searchComposition
                    .frame(minHeight: 320, alignment: .center)

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
        .background { OrielTheme.startPageBackground }
        .onAppear {
            if !reduceMotion {
                searchFocused = true
            }
        }
    }

    /// First viewport: brand + one search field + engine hint.
    private var searchComposition: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                Text(BrowserConstants.productName)
                    .font(.system(size: 48, weight: .bold, design: .serif))
                    .tracking(-1.2)
                    .foregroundStyle(.primary)

                Text("A calm view of the web.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .combine)

            searchField

            Text("Search via \(activeEngine.displayName)")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: activeEngine)

            enginePicker

            HStack {
                Spacer()
                Button("Settings") {
                    environment.showSettings = true
                }
                .font(.footnote.weight(.semibold))
            }
        }
        .padding(.top, 48)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.title3.weight(.medium))
                .foregroundStyle(searchFocused ? OrielTheme.brandPrimary : .secondary)

            TextField("Search or enter address", text: $query)
                .textFieldStyle(.plain)
                .font(.title3)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                .autocorrectionDisabled()
                #endif
                .focused($searchFocused)
                .onSubmit(submitSearch)
                .accessibilityLabel("Oriel search")
                .accessibilityHint("Searches with \(activeEngine.displayName) when the text is not a web address")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: submitSearch) {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color.secondary.opacity(0.4)
                                     : OrielTheme.brandPrimary)
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 18)
        .frame(height: OrielTheme.searchFieldHeight)
        .background {
            RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
                .fill(.regularMaterial)
                .shadow(
                    color: searchFocused ? OrielTheme.brandPrimary.opacity(0.22) : .black.opacity(0.06),
                    radius: searchFocused && !reduceMotion ? 16 : 8,
                    y: 4
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
                .strokeBorder(
                    searchFocused ? OrielTheme.brandPrimary.opacity(0.55) : Color.primary.opacity(0.08),
                    lineWidth: searchFocused ? 1.5 : 1
                )
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: searchFocused)
    }

    private var enginePicker: some View {
        HStack(spacing: 0) {
            ForEach(SearchEngine.allCases) { engine in
                let selected = activeEngine == engine
                Button {
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                        environment.setSearchEngine(engine)
                        tab.searchEngine = engine
                    }
                } label: {
                    Text(engine.displayName)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .background {
                            if selected {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.background.opacity(0.9))
                                    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityLabel("\(engine.displayName) search engine")
            }
        }
        .padding(3)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search engine")
    }

    private func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let engine = environment.settings.searchEngine
        tab.searchEngine = engine
        let url = URLParser.resolve(trimmed, searchEngine: engine)
        tab.load(url)
        query = ""
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
