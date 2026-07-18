import SwiftUI

struct StartPageView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: BrowserTab

    @State private var query = ""
    @State private var appeared = false
    @State private var startSuggestions: [SearchSuggestion] = []
    @State private var suggestionTask: Task<Void, Never>?
    @FocusState private var searchFocused: Bool

    private var activeEngine: SearchEngine {
        environment.settings.searchEngine
    }

    private var pageScheme: ColorScheme {
        environment.settings.backgroundTheme.resolvedColorScheme(system: systemColorScheme)
    }

    private var accent: Color {
        environment.settings.accentTheme.readable(on: pageScheme)
    }

    private var stats: PrivacyStats {
        environment.privacyStats
    }

    private var isWide: Bool {
        sizeClass == .regular
    }

    private var suggestedItems: [(String, String)] {
        [
            ("openoriel.com", BrowserConstants.productWebsiteURL.absoluteString),
            ("DuckDuckGo", "https://duckduckgo.com"),
            ("Wikipedia", "https://wikipedia.org"),
            ("Apple Developer", "https://developer.apple.com")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                topBand
                    .padding(.top, isWide ? 36 : 28)

                searchBlock

                if isWide {
                    HStack(alignment: .top, spacing: 16) {
                        if !environment.bookmarks.favorites.isEmpty {
                            tileSection(
                                title: "Favorites",
                                items: environment.bookmarks.favorites.prefix(8).compactMap { bookmark -> (String, String)? in
                                    guard let url = bookmark.urlString else { return nil }
                                    return (bookmark.title, url)
                                }
                            )
                        }
                        privacyCard
                            .frame(maxWidth: 320)
                    }
                } else {
                    privacyCard
                    if !environment.bookmarks.favorites.isEmpty {
                        tileSection(
                            title: "Favorites",
                            items: environment.bookmarks.favorites.prefix(8).compactMap { bookmark -> (String, String)? in
                                guard let url = bookmark.urlString else { return nil }
                                return (bookmark.title, url)
                            }
                        )
                    }
                }

                if isWide {
                    HStack(alignment: .top, spacing: 16) {
                        if !environment.history.recentSites.isEmpty {
                            tileSection(
                                title: "Recent",
                                items: environment.history.recentSites.prefix(6).map {
                                    ($0.title, $0.urlString)
                                }
                            )
                        }
                        tileSection(title: "Suggested", items: suggestedItems)
                    }
                } else {
                    if !environment.history.recentSites.isEmpty {
                        tileSection(
                            title: "Recent",
                            items: environment.history.recentSites.prefix(6).map {
                                ($0.title, $0.urlString)
                            }
                        )
                    }
                    tileSection(title: "Suggested", items: suggestedItems)
                }

                if !environment.installedWebApps.apps.isEmpty {
                    tileSection(
                        title: "Web Apps",
                        items: environment.installedWebApps.apps.prefix(8).map {
                            ($0.name, $0.startURL.absoluteString)
                        }
                    )
                }

                footerLinks
                Spacer(minLength: 40)
            }
            .padding(.horizontal, isWide ? 36 : 22)
            .frame(maxWidth: isWide ? 920 : 560)
            .frame(maxWidth: .infinity)
            .opacity(appeared || reduceMotion ? 1 : 0)
            .offset(y: appeared || reduceMotion ? 0 : 10)
        }
        .background {
            OrielTheme.startPageBackground(
                accent: environment.settings.accentTheme,
                background: environment.settings.backgroundTheme,
                scheme: systemColorScheme
            )
        }
        // Lock semantic colors to the page wash so Midnight/Paper never fight system text.
        .environment(\.colorScheme, pageScheme)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.45)) {
                    appeared = true
                }
            }
            // On phone-width layouts the bottom address bar is primary — don't steal focus.
            if isWide {
                if reduceMotion {
                    searchFocused = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        searchFocused = true
                    }
                }
            }
        }
    }

    private var topBand: some View {
        Group {
            if isWide {
                HStack(alignment: .center, spacing: 24) {
                    brandBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                    quickActions
                }
            } else {
                VStack(spacing: 18) {
                    brandBlock
                    quickActions
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandBlock: some View {
        HStack(spacing: 16) {
            OrielMark(size: isWide ? 52 : 44)
                .shadow(color: accent.opacity(0.2), radius: 14, y: 5)

            VStack(alignment: isWide ? .leading : .center, spacing: 4) {
                Text(BrowserConstants.productName)
                    .font(.system(size: isWide ? 40 : 36, weight: .semibold, design: .serif))
                    .tracking(-0.8)
                    .foregroundStyle(.primary)
                Text("A calm view of the web.")
                    .font(.title3.weight(.regular))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: isWide ? .infinity : nil, alignment: isWide ? .leading : .center)
        }
        .frame(maxWidth: .infinity, alignment: isWide ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            quickChip(systemImage: "gearshape", title: "Settings") {
                environment.showSettings = true
            }
            quickChip(systemImage: "hand.raised.fill", title: "Shields") {
                environment.showPrivacyShield = true
            }
            quickChip(systemImage: "safari", title: "Site") {
                tab.openProductSite()
            }
        }
    }

    private func quickChip(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(OrielTheme.surfaceFill(for: pageScheme), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary.opacity(0.85))
    }

    private var searchBlock: some View {
        VStack(spacing: 12) {
            searchField
            if searchFocused && !startSuggestions.isEmpty {
                startSuggestionList
            }
            HStack {
                Text("via \(activeEngine.displayName)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer(minLength: 0)
                enginePicker
            }

            if activeEngine == .google {
                Button {
                    if let url = URL(string: "https://accounts.google.com/signin") {
                        tab.load(url)
                    }
                } label: {
                    Text("Sign in to Google")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(accent.opacity(0.14), in: Capsule())
                        .overlay {
                            Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityHint("Opens Google Account sign-in in this tab.")
            }
        }
    }

    private var privacyCard: some View {
        Button {
            environment.showPrivacyShield = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Shields", systemImage: "hand.raised.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 10) {
                    privacyStat(
                        title: "Trackers",
                        session: stats.blockedRequestsSession,
                        lifetime: stats.blockedRequestsLifetime,
                        systemImage: "eye.slash"
                    )
                    privacyStat(
                        title: "Cookies",
                        session: stats.cookiesBlockedSession,
                        lifetime: stats.cookiesBlockedLifetime,
                        systemImage: "cookie"
                    )
                }

                HStack(spacing: 8) {
                    Image(systemName: environment.privacy.blockThirdPartyCookies ? "checkmark.shield.fill" : "shield")
                        .foregroundStyle(environment.privacy.blockThirdPartyCookies ? accent : Color.secondary)
                    Text(
                        environment.privacy.blockThirdPartyCookies
                            ? "Third-party cookies limited"
                            : "Third-party cookies allowed"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                OrielTheme.surfaceFill(for: pageScheme),
                in: RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                    .strokeBorder(accent.opacity(0.22), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shields summary")
        .accessibilityHint("Opens Shields for tracker and cookie details")
        .accessibilityValue(
            "\(stats.blockedRequestsSession) trackers this session, \(stats.cookiesBlockedSession) cookies this session"
        )
    }

    private func privacyStat(
        title: String,
        session: Int,
        lifetime: Int,
        systemImage: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .labelStyle(.titleAndIcon)
            Text("\(session)")
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
            Text("session · \(lifetime) total")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color.primary.opacity(pageScheme == .dark ? 0.1 : 0.045),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(searchFocused ? accent : Color.secondary)

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
                .onChange(of: query) { _, newValue in
                    scheduleStartSuggestions(for: newValue)
                }
                .accessibilityLabel("Oriel search")
                .accessibilityHint("Searches with \(activeEngine.displayName) when the text is not a web address")

            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: submitSearch) {
                Text("Go")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.primary.opacity(0.06)
                        : accent.opacity(0.18),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(
                                query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.primary.opacity(0.08)
                                : accent.opacity(0.4),
                                lineWidth: 1
                            )
                    }
                    .foregroundStyle(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? Color.secondary
                        : accent
                    )
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 16)
        .frame(height: OrielTheme.searchFieldHeight)
        .background(
            OrielTheme.surfaceFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
                .strokeBorder(
                    searchFocused
                        ? accent.opacity(0.45)
                        : OrielTheme.hairline(for: pageScheme),
                    lineWidth: searchFocused ? 1.5 : 1
                )
        }
        .shadow(
            color: Color.black.opacity(pageScheme == .dark ? 0.28 : 0.06),
            radius: searchFocused ? 16 : 10,
            y: 4
        )
    }

    private var enginePicker: some View {
        HStack(spacing: 8) {
            ForEach(SearchEngine.allCases) { engine in
                let selected = activeEngine == engine
                Button {
                    environment.setSearchEngine(engine)
                    tab.searchEngine = engine
                } label: {
                    Text(engine.displayName)
                        .font(.caption.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? accent : Color.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selected ? accent.opacity(0.14) : Color.primary.opacity(0.04),
                            in: Capsule()
                        )
                        .overlay {
                            Capsule()
                                .strokeBorder(
                                    selected ? accent.opacity(0.35) : Color.primary.opacity(0.08),
                                    lineWidth: 1
                                )
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityLabel("\(engine.displayName) search engine")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search engine")
    }

    private var footerLinks: some View {
        HStack(spacing: 10) {
            footerChip(BrowserConstants.productWebsiteHost) {
                tab.openProductSite()
            }
            footerChip(BrowserConstants.publisherName) {
                tab.openPublisherSite()
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 4)
    }

    private func footerChip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(0.05), in: Capsule())
                .overlay {
                    Capsule().strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var startSuggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startSuggestions) { item in
                Button {
                    applyStartSuggestion(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.source == .bookmark ? "bookmark" : (item.source == .history ? "clock" : "magnifyingglass"))
                            .font(.footnote)
                            .foregroundStyle(accent)
                            .frame(width: 18)
                        Text(item.text)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if item.id != startSuggestions.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(
            OrielTheme.surfaceFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func applyStartSuggestion(_ item: SearchSuggestion) {
        if let url = item.url {
            tab.load(url)
        } else {
            query = item.text
            submitSearch()
        }
        startSuggestions = []
        searchFocused = false
    }

    private func scheduleStartSuggestions(for raw: String) {
        suggestionTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            startSuggestions = []
            return
        }
        suggestionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            let results = await environment.searchSuggestions.suggestions(
                for: trimmed,
                engine: activeEngine,
                history: environment.history,
                bookmarks: environment.bookmarks
            )
            guard !Task.isCancelled else { return }
            startSuggestions = results
        }
    }

    private func submitSearch() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let engine = environment.settings.searchEngine
        tab.searchEngine = engine
        tab.load(URLParser.resolve(trimmed, searchEngine: engine))
        query = ""
        startSuggestions = []
    }

    private func tileSection(title: String, items: [(String, String)]) -> some View {
        let pairs = Array(items)
        return VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.9)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 140), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, item in
                    Button {
                        if let url = URL(string: item.1) {
                            tab.load(url)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            FaviconImage(pageURL: URL(string: item.1), size: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.0)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(item.1.replacingOccurrences(of: "https://", with: ""))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
                        .background(
                            OrielTheme.surfaceFill(for: pageScheme),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
