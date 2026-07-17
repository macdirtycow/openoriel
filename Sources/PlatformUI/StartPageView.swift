import SwiftUI

struct StartPageView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: BrowserTab

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    private var activeEngine: SearchEngine {
        environment.settings.searchEngine
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 40) {
                hero
                    .frame(maxWidth: .infinity)
                    .padding(.top, 56)

                if !environment.bookmarks.favorites.isEmpty {
                    section(title: "Favorites") {
                        linkRows(items: environment.bookmarks.favorites.map {
                            ($0.title, $0.urlString)
                        })
                    }
                }

                if !environment.history.recentSites.isEmpty {
                    section(title: "Recent") {
                        linkRows(items: environment.history.recentSites.prefix(6).map {
                            ($0.title, $0.urlString)
                        })
                    }
                }

                section(title: "Suggested") {
                    linkRows(items: [
                        ("openoriel.com", BrowserConstants.productWebsiteURL.absoluteString),
                        ("DuckDuckGo", "https://duckduckgo.com"),
                        ("Wikipedia", "https://wikipedia.org"),
                        ("Apple Developer", "https://developer.apple.com")
                    ])
                }

                footerLinks
                    .padding(.top, 8)

                Spacer(minLength: 48)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: 560)
            .frame(maxWidth: .infinity)
        }
        .background {
            Group {
                if colorScheme == .dark {
                    OrielTheme.startPageBackgroundDark
                } else {
                    OrielTheme.startPageBackground
                }
            }
        }
        .onAppear {
            if !reduceMotion {
                searchFocused = true
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 22) {
            VStack(spacing: 6) {
                Text(BrowserConstants.productName)
                    .font(.system(size: 44, weight: .semibold, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(.primary)

                Text("A calm view of the web.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            searchField

            Text("via \(activeEngine.displayName)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(0.6)

            enginePicker

            if activeEngine == .google {
                Button {
                    if let url = URL(string: "https://accounts.google.com/signin") {
                        tab.load(url)
                    }
                } label: {
                    Text("Sign in to Google")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(OrielTheme.brandPrimary)
                .accessibilityHint("Opens Google Account sign-in in this tab.")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("Search or enter address", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
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
                    Image(systemName: "xmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: submitSearch) {
                Text("Go")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary
                        : Color.primary
                    )
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 16)
        .frame(height: OrielTheme.searchFieldHeight)
        .background(
            colorScheme == .dark
                ? Color.white.opacity(0.06)
                : Color.white.opacity(0.85),
            in: RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
                .strokeBorder(
                    Color.primary.opacity(searchFocused ? 0.28 : 0.12),
                    lineWidth: 1
                )
        }
    }

    private var enginePicker: some View {
        HStack(spacing: 16) {
            ForEach(SearchEngine.allCases) { engine in
                let selected = activeEngine == engine
                Button {
                    environment.setSearchEngine(engine)
                    tab.searchEngine = engine
                } label: {
                    Text(engine.displayName)
                        .font(.caption.weight(selected ? .semibold : .regular))
                        .foregroundStyle(selected ? Color.primary : Color.secondary)
                        .padding(.bottom, 2)
                        .overlay(alignment: .bottom) {
                            Rectangle()
                                .fill(selected ? OrielTheme.brandPrimary : Color.clear)
                                .frame(height: 1.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityLabel("\(engine.displayName) search engine")
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search engine")
    }

    private var footerLinks: some View {
        HStack(spacing: 20) {
            Button("Settings") {
                environment.showSettings = true
            }
            Button(BrowserConstants.productWebsiteHost) {
                tab.openProductSite()
            }
            Button(BrowserConstants.publisherName) {
                tab.openPublisherSite()
            }
            Spacer(minLength: 0)
        }
        .font(.footnote.weight(.medium))
        .foregroundStyle(.secondary)
        .buttonStyle(.plain)
    }

    private func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let engine = environment.settings.searchEngine
        tab.searchEngine = engine
        tab.load(URLParser.resolve(trimmed, searchEngine: engine))
        query = ""
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.8)
            content()
        }
    }

    private func linkRows(items: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    if let url = URL(string: item.1) {
                        tab.load(url)
                    }
                } label: {
                    HStack(spacing: 12) {
                        FaviconImage(pageURL: URL(string: item.1), size: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.0)
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text(item.1.replacingOccurrences(of: "https://", with: ""))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < items.count - 1 {
                    Divider()
                        .opacity(0.45)
                }
            }
        }
    }
}
