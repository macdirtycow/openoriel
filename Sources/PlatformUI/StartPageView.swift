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
        if let prefersDark = environment.settings.extensionThemePrefersDark {
            return prefersDark ? .dark : .light
        }
        return environment.settings.backgroundTheme.resolvedColorScheme(system: systemColorScheme)
    }

    private var accent: Color {
        if environment.settings.usesExtensionTheme {
            return environment.settings.brandColor
        }
        return environment.settings.accentTheme.readable(on: pageScheme)
    }

    private var activeExtensionThemeNTPImageURL: URL? {
        guard let id = environment.settings.activeExtensionThemeID,
              let theme = environment.extensionThemes.themes.first(where: { $0.id == id }) else {
            return nil
        }
        return environment.extensionThemes.ntpImageURL(for: theme)
    }

    private var stats: PrivacyStats {
        environment.privacyStats
    }

    private var isWide: Bool {
        sizeClass == .regular
    }

    private var contentSpacing: CGFloat { isWide ? 22 : 18 }

    private var suggestedItems: [(String, String)] {
        if environment.settings.edition.isPulse {
            return [
                ("Twitch", "https://www.twitch.tv"),
                ("YouTube", "https://www.youtube.com"),
                ("Discord", "https://discord.com/app"),
                ("Steam", "https://store.steampowered.com"),
                ("openoriel.com", BrowserConstants.productWebsiteURL.absoluteString),
                ("DuckDuckGo", "https://duckduckgo.com")
            ]
        }
        return [
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
                scheme: pageScheme,
                customAccent: (environment.settings.usesExtensionTheme || environment.settings.edition.isPulse)
                    ? environment.settings.brandColor : nil,
                customBackground: environment.settings.customBackgroundColor,
                ntpImageURL: activeExtensionThemeNTPImageURL
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if environment.settings.edition.isPulse,
               let wallpaper = PulseWallpaper(rawValue: environment.settings.pulseWallpaperID),
               wallpaper != .off {
                wallpaper.background(accent: accent)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: contentSpacing) {
                    topBand
                        .padding(.top, isWide ? 28 : 20)

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
                        compactPrivacyStrip
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
                    Spacer(minLength: 36)
                }
                .padding(.horizontal, isWide ? OrielLayout.startPageGutterRegular : OrielLayout.startPageGutterCompact)
                .frame(maxWidth: isWide ? OrielLayout.startPageMaxWidthRegular : OrielLayout.startPageMaxWidthCompact)
                .frame(maxWidth: .infinity)
                .opacity(appeared || reduceMotion ? 1 : 0)
                .offset(y: appeared || reduceMotion ? 0 : 10)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Soft/Paper/etc. paint against pageScheme — lock before children read Environment.
        .environment(\.colorScheme, pageScheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: environment.settings.backgroundTheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.28), value: environment.settings.accentTheme)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: environment.settings.edition)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.88)) {
                    appeared = true
                }
            }
            if isWide {
                if reduceMotion {
                    searchFocused = true
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
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
        VStack(spacing: isWide ? 0 : 12) {
            if isWide {
                HStack(spacing: 16) {
                    OrielMark(size: 48)
                        .shadow(color: accent.opacity(0.16), radius: 14, y: 5)
                    brandCopy(alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                OrielMark(size: 52)
                    .shadow(color: accent.opacity(0.16), radius: 16, y: 6)
                brandCopy(alignment: .center)
            }
        }
        .frame(maxWidth: .infinity, alignment: isWide ? .leading : .center)
        .accessibilityElement(children: .combine)
    }

    private func brandCopy(alignment: HorizontalAlignment) -> some View {
        let edition = environment.settings.edition
        return VStack(alignment: alignment, spacing: 4) {
            Text(EditionBranding.productName(for: edition))
                .font(EditionBranding.productTitleFont(for: edition, size: isWide ? 34 : 30))
                .tracking(EditionBranding.productTitleTracking(for: edition))
                .foregroundStyle(.primary)
            Text(EditionBranding.tagline(for: edition))
                .font(.system(.callout, design: .default).weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    /// Compact: 2×2 grid so Settings/Shields never clip off-screen.
    /// Wide: single row.
    private var quickActions: some View {
        Group {
            if isWide {
                HStack(spacing: 8) {
                    ProfileSwitcherControl(style: .chip)
                    quickChip(systemImage: "gearshape", title: "Settings") {
                        environment.showSettings = true
                    }
                    quickChip(systemImage: "hand.raised.fill", title: "Shields") {
                        environment.showPrivacyShield = true
                    }
                    if environment.settings.edition.isPulse {
                        quickChip(systemImage: "bolt.horizontal", title: "Pulse") {
                            environment.showPulsePerformance = true
                        }
                    }
                    quickChip(systemImage: "safari", title: "Site") {
                        tab.openProductSite()
                    }
                }
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 8),
                        GridItem(.flexible(), spacing: 8)
                    ],
                    spacing: 8
                ) {
                    profileActionCell
                    quickActionCell(systemImage: "gearshape", title: "Settings") {
                        environment.showSettings = true
                    }
                    quickActionCell(systemImage: "hand.raised.fill", title: "Shields") {
                        environment.showPrivacyShield = true
                    }
                    if environment.settings.edition.isPulse {
                        quickActionCell(systemImage: "bolt.horizontal", title: "Pulse") {
                            environment.showPulsePerformance = true
                        }
                    }
                    quickActionCell(systemImage: "safari", title: "Site") {
                        tab.openProductSite()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var profileActionCell: some View {
        Menu {
            Section("Profiles") {
                ForEach(environment.profiles.profiles) { profile in
                    Button {
                        environment.applyProfile(id: profile.id)
                    } label: {
                        if profile.id == environment.profiles.activeProfileID {
                            Label(profile.name, systemImage: "checkmark")
                        } else {
                            Text(profile.name)
                        }
                    }
                }
            }
            Divider()
            Button("Manage Profiles…") { environment.showProfiles = true }
        } label: {
            quickActionLabel(
                systemImage: "person.crop.circle.fill",
                title: environment.profiles.activeProfile.name
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Profile, \(environment.profiles.activeProfile.name)")
    }

    private func quickActionCell(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            quickActionLabel(systemImage: systemImage, title: title)
        }
        .buttonStyle(.plain)
    }

    private func quickActionLabel(systemImage: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
                .frame(width: 18)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(
            OrielTheme.elevatedFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous))
    }

    private func quickChip(systemImage: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    OrielTheme.elevatedFill(for: pageScheme),
                    in: Capsule(style: .continuous)
                )
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
                }
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
            if isWide {
                enginePicker
            } else {
                engineMenu
            }
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
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }

            Button(action: submitSearch) {
                Text("Go")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.primary.opacity(0.06)
                            : accent,
                        in: Capsule(style: .continuous)
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
        .padding(.horizontal, 16)
        .frame(height: OrielTheme.searchFieldHeight)
        .background(
            OrielTheme.elevatedFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.searchFieldRadius, style: .continuous)
                .strokeBorder(
                    searchFocused ? accent.opacity(0.45) : OrielTheme.hairline(for: pageScheme),
                    lineWidth: searchFocused ? 1.5 : 1
                )
        }
        .shadow(color: OrielTheme.softShadow(for: pageScheme), radius: searchFocused ? 14 : 8, y: 3)
    }

    private var engineMenu: some View {
        Menu {
            ForEach(SearchEngine.allCases) { engine in
                Button {
                    environment.setSearchEngine(engine)
                    tab.searchEngine = engine
                } label: {
                    if engine == activeEngine {
                        Label(engine.displayName, systemImage: "checkmark")
                    } else {
                        Text(engine.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: activeEngine.systemImage)
                    .font(.caption.weight(.semibold))
                Text(activeEngine.displayName)
                    .font(.caption.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                OrielTheme.elevatedFill(for: pageScheme),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Search engine, \(activeEngine.displayName)")
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
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            selected ? accent.opacity(0.12) : Color.clear,
                            in: Capsule(style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? [.isSelected] : [])
                .accessibilityLabel("\(engine.displayName) search engine")
            }
        }
        .padding(3)
        .background(
            OrielTheme.elevatedFill(for: pageScheme),
            in: Capsule(style: .continuous)
        )
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search engine")
    }

    // MARK: - Shields

    /// Compact Shields summary for phone / narrow — keeps the first screen from becoming a dashboard.
    private var compactPrivacyStrip: some View {
        Button {
            environment.showPrivacyShield = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "hand.raised.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Shields")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(
                        environment.privacy.contentBlockingEnabled
                            ? "\(stats.blockedRequestsSession) blocked this session"
                            : "Protection off"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                OrielTheme.elevatedFill(for: pageScheme),
                in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                    .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shields summary")
        .accessibilityHint("Opens Shields for tracker and cookie details")
    }

    private var privacyCard: some View {
        Button {
            environment.showPrivacyShield = true
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Text("Shields")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.8)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 0) {
                    privacyStat(
                        title: "Trackers",
                        value: "\(stats.blockedRequestsSession)",
                        subtitle: "\(stats.blockedRequestsLifetime) total"
                    )
                    Divider()
                        .frame(height: 44)
                        .padding(.horizontal, 12)
                    privacyStat(
                        title: "Cookies",
                        value: "\(stats.cookiesBlockedSession)",
                        subtitle: "\(stats.cookiesBlockedLifetime) total"
                    )
                    Divider()
                        .frame(height: 44)
                        .padding(.horizontal, 12)
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
                            ? "Protection on while you browse"
                            : "Turn Shields on to block trackers"
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                OrielTheme.elevatedFill(for: pageScheme),
                in: RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                    .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
            }
            .shadow(color: OrielTheme.softShadow(for: pageScheme), radius: 10, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shields summary")
        .accessibilityHint("Opens Shields for tracker and cookie details")
        .accessibilityValue(
            "\(stats.blockedRequestsSession) trackers, \(stats.cookiesBlockedSession) cookies, \(Self.formatMinutes(stats.minutesSavedSession)) saved"
        )
    }

    private func privacyStat(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
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
            OrielTheme.elevatedFill(for: pageScheme),
            in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
        }
        .shadow(color: OrielTheme.softShadow(for: pageScheme), radius: 8, y: 2)
    }

    private func tileSection(title: String, items: [(String, String)]) -> some View {
        let pairs = Array(items)
        return VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.9)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: isWide ? 168 : 148), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, item in
                    Button {
                        if let url = URL(string: item.1) {
                            tab.load(url)
                        }
                    } label: {
                        HStack(spacing: 11) {
                            FaviconImage(pageURL: URL(string: item.1), size: 18)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.0)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(displayHost(item.1))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                        .background(
                            OrielTheme.elevatedFill(for: pageScheme),
                            in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                                .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous))
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
