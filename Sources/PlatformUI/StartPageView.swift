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

    private var contentSpacing: CGFloat { isWide ? 22 : 20 }

    private var suggestedItems: [(String, String)] {
        [
            ("openoriel.com", BrowserConstants.productWebsiteURL.absoluteString),
            ("DuckDuckGo", "https://duckduckgo.com"),
            ("Wikipedia", "https://wikipedia.org"),
            ("Apple Developer", "https://developer.apple.com")
        ]
    }

    var body: some View {
        ZStack {
            OrielTheme.startPageBackground(
                accent: environment.settings.accentTheme,
                background: environment.settings.backgroundTheme,
                scheme: pageScheme
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    topBand
                        .padding(.top, isWide ? 28 : 22)

                    searchBlock

                    if isWide {
                        HStack(alignment: .top, spacing: 14) {
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
                                .frame(maxWidth: 300)
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
                        HStack(alignment: .top, spacing: 14) {
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
                    Spacer(minLength: 28)
                }
                .padding(.horizontal, isWide ? 40 : 20)
                .frame(maxWidth: isWide ? 880 : 560)
                .frame(maxWidth: .infinity)
                .opacity(appeared || reduceMotion ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 8)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Soft/Paper/etc. paint against pageScheme — lock before children read Environment.
        .environment(\.colorScheme, pageScheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: environment.settings.backgroundTheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: environment.settings.accentTheme)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.easeOut(duration: 0.4)) {
                    appeared = true
                }
            }
            if isWide {
                if reduceMotion {
                    searchFocused = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        searchFocused = true
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var topBand: some View {
        Group {
            if isWide {
                HStack(alignment: .center, spacing: 20) {
                    brandBlock
                        .frame(maxWidth: .infinity, alignment: .leading)
                    quickActions
                }
            } else {
                VStack(spacing: 14) {
                    brandBlock
                    quickActions
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var brandBlock: some View {
        HStack(spacing: 14) {
            OrielMark(size: isWide ? 44 : 40)
                .shadow(color: accent.opacity(0.18), radius: 12, y: 4)

            VStack(alignment: isWide ? .leading : .center, spacing: 2) {
                Text(BrowserConstants.productName)
                    .font(.system(size: isWide ? 34 : 30, weight: .semibold, design: .serif))
                    .tracking(-0.6)
                    .foregroundStyle(.primary)
                Text("A calm view of the web.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: isWide ? .infinity : nil, alignment: isWide ? .leading : .center)
        }
        .frame(maxWidth: .infinity, alignment: isWide ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private var quickActions: some View {
        HStack(spacing: 6) {
            ProfileSwitcherControl(style: .chip)
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
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(Color.primary.opacity(pageScheme == .dark ? 0.08 : 0.05), in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    // MARK: - Search

    private var searchBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            searchField
            if searchFocused && !startSuggestions.isEmpty {
                startSuggestionList
            }
            searchMetaRow
        }
    }

    private var searchMetaRow: some View {
        HStack(alignment: .center, spacing: 10) {
            enginePicker
            Spacer(minLength: 8)
            if activeEngine == .google {
                Button {
                    if let url = URL(string: "https://accounts.google.com/signin") {
                        tab.load(url)
                    }
                } label: {
                    Text("Sign in")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Sign in to Google")
                .accessibilityHint("Opens Google Account sign-in in this tab.")
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline.weight(.medium))
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
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: submitSearch) {
                Text("Go")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.primary.opacity(0.06)
                            : accent,
                        in: Capsule()
                    )
                    .foregroundStyle(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.white
                    )
            }
            .buttonStyle(.plain)
            .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel("Search")
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            OrielTheme.surfaceFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    searchFocused ? accent.opacity(0.4) : OrielTheme.hairline(for: pageScheme),
                    lineWidth: 1
                )
        }
    }

    private var enginePicker: some View {
        HStack(spacing: 4) {
            ForEach(SearchEngine.allCases) { engine in
                let selected = activeEngine == engine
                Button {
                    environment.setSearchEngine(engine)
                    tab.searchEngine = engine
                } label: {
                    Text(engine.displayName)
                        .font(.caption2.weight(selected ? .semibold : .medium))
                        .foregroundStyle(selected ? accent : Color.secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            selected ? accent.opacity(0.12) : Color.clear,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityLabel("\(engine.displayName) search engine")
            }
        }
        .padding(3)
        .background(Color.primary.opacity(pageScheme == .dark ? 0.06 : 0.04), in: Capsule())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search engine")
    }

    // MARK: - Shields

    private var privacyCard: some View {
        Button {
            environment.showPrivacyShield = true
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("Shields")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.7)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.quaternary)
                }

                HStack(spacing: 0) {
                    privacyStat(
                        title: "Trackers",
                        value: "\(stats.blockedRequestsSession)",
                        subtitle: "\(stats.blockedRequestsLifetime) total"
                    )
                    Divider()
                        .frame(height: 40)
                        .padding(.horizontal, 10)
                    privacyStat(
                        title: "Cookies",
                        value: "\(stats.cookiesBlockedSession)",
                        subtitle: "\(stats.cookiesBlockedLifetime) total"
                    )
                    Divider()
                        .frame(height: 40)
                        .padding(.horizontal, 10)
                    privacyStat(
                        title: "Time saved",
                        value: Self.formatMinutes(stats.minutesSavedSession),
                        subtitle: "\(Self.formatMinutes(stats.minutesSavedLifetime)) total"
                    )
                }

                HStack(spacing: 6) {
                    Image(systemName: environment.privacy.contentBlockingEnabled ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(environment.privacy.contentBlockingEnabled ? accent : Color.secondary)
                    Text(
                        environment.privacy.contentBlockingEnabled
                            ? "Shields on — counts update as you browse"
                            : "Shields off — enable to block trackers"
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                OrielTheme.surfaceFill(for: pageScheme),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shields summary")
        .accessibilityHint("Opens Shields for tracker and cookie details")
        .accessibilityValue(
            "\(stats.blockedRequestsSession) trackers, \(stats.cookiesBlockedSession) cookies, \(Self.formatMinutes(stats.minutesSavedSession)) saved this session"
        )
    }

    private func privacyStat(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.quaternary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func formatMinutes(_ minutes: Double) -> String {
        if minutes < 0.05 {
            return "0 min"
        }
        if minutes < 10 {
            let rounded = (minutes * 10).rounded() / 10
            if rounded == rounded.rounded(.towardZero) {
                return "\(Int(rounded)) min"
            }
            return String(format: "%.1f min", rounded)
        }
        return "\(Int(minutes.rounded())) min"
    }

    // MARK: - Tiles & footer

    private var footerLinks: some View {
        HStack(spacing: 0) {
            footerLink(BrowserConstants.productWebsiteHost) {
                tab.openProductSite()
            }
            Text("·")
                .font(.footnote)
                .foregroundStyle(.quaternary)
                .padding(.horizontal, 8)
            footerLink(BrowserConstants.publisherName) {
                tab.openPublisherSite()
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 2)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.footnote.weight(.medium))
                .foregroundStyle(.tertiary)
        }
        .buttonStyle(.plain)
    }

    private var startSuggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(startSuggestions) { item in
                Button {
                    applyStartSuggestion(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: item.source == .bookmark ? "bookmark" : (item.source == .history ? "clock" : "magnifyingglass"))
                            .font(.caption)
                            .foregroundStyle(accent)
                            .frame(width: 16)
                        Text(item.text)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if item.id != startSuggestions.last?.id {
                    Divider().padding(.leading, 38)
                }
            }
        }
        .background(
            OrielTheme.surfaceFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
        }
    }

    private func tileSection(title: String, items: [(String, String)]) -> some View {
        let pairs = Array(items)
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
                .tracking(1.0)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: isWide ? 160 : 140), spacing: 8)],
                spacing: 8
            ) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, item in
                    Button {
                        if let url = URL(string: item.1) {
                            tab.load(url)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            FaviconImage(pageURL: URL(string: item.1), size: 16)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(item.0)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(displayHost(item.1))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 11)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        .background(
                            OrielTheme.surfaceFill(for: pageScheme),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func displayHost(_ urlString: String) -> String {
        if let host = URL(string: urlString)?.host {
            return host.replacingOccurrences(of: "www.", with: "")
        }
        return urlString
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
    }

    // MARK: - Actions

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
}
