import SwiftUI

/// Universal extension/theme browser — one search across Chrome, Firefox, and Safari.
/// Preferred over opening the store websites (iPhone, iPad, and Mac).
struct OrielStoreView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var kind: ExtensionStoreItem.Kind = .extension
    @State private var category: StoreBrowseCategory = .featuredExtensions
    @State private var sort: StoreBrowseSort = .popular
    @State private var query = ""
    @State private var listings: [UnifiedStoreListing] = []
    @State private var page = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var canLoadMore = true
    @State private var errorMessage: String?
    @State private var installingID: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var installHint: String?
    @State private var pendingCompatInstall: UnifiedStoreListing?
    @State private var showCompatWarning = false
    @State private var installError: String?
    @State private var installStatus: String?
    @FocusState private var searchFocused: Bool

    /// When true (sheet presentation), show a Done button. Hidden inside Extensions navigation.
    var showsDoneButton: Bool = true

    private var accent: Color { environment.settings.brandColor }
    private var categories: [StoreBrowseCategory] { StoreBrowseCategory.categories(for: kind) }
    private var sortOptions: [StoreBrowseSort] { StoreBrowseSort.options(forQuery: query) }

    var body: some View {
        Group {
            #if os(macOS)
            storeForm
                .formStyle(.grouped)
            #else
            storeForm
                .listStyle(.insetGrouped)
            #endif
        }
        .navigationTitle("Oriel Store")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    ForEach(sortOptions) { option in
                        Button {
                            sort = option
                        } label: {
                            if option == sort {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .help("Sort catalog")
            }
        }
        .task(id: catalogTaskID) {
            await reload(debounce: false, reset: true)
        }
        .onChange(of: query) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await reload(debounce: true, reset: true)
            }
        }
        .onChange(of: kind) { _, newKind in
            category = newKind == .theme ? .featuredThemes : .featuredExtensions
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                sort = .popular
            }
        }
        .onAppear {
            #if os(macOS)
            environment.extensions.refreshSafariCandidates()
            #endif
        }
        .alert("Safari extension", isPresented: Binding(
            get: { installHint != nil },
            set: { if !$0 { installHint = nil } }
        )) {
            Button("OK", role: .cancel) { installHint = nil }
        } message: {
            Text(installHint ?? "")
        }
        .alert("Couldn’t install", isPresented: Binding(
            get: { installError != nil },
            set: { if !$0 { installError = nil } }
        )) {
            Button("OK", role: .cancel) { installError = nil }
        } message: {
            Text(installError ?? "")
        }
        .confirmationDialog(
            "Limited WebKit support",
            isPresented: $showCompatWarning,
            titleVisibility: .visible,
            presenting: pendingCompatInstall
        ) { listing in
            Button("Install anyway") {
                showCompatWarning = false
                Task { await performInstall(listing) }
            }
            Button("Cancel", role: .cancel) {
                showCompatWarning = false
                pendingCompatInstall = nil
            }
        } message: { listing in
            Text(ExtensionCompatibility.assess(listing).installWarning)
        }
    }

    private var catalogTaskID: String {
        "\(kind.rawValue)|\(category.id)|\(sort.rawValue)"
    }

    private var storeForm: some View {
        Form {
            Section {
                Picker("Kind", selection: $kind) {
                    Text("Extensions").tag(ExtensionStoreItem.Kind.extension)
                    Text("Themes").tag(ExtensionStoreItem.Kind.theme)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 6, trailing: 16))
                .listRowBackground(Color.clear)

                storeSearchField
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)

                categoryChips
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
            } footer: {
                Text(footerBlurb)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let installStatus {
                Section {
                    Label(installStatus, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            catalogSection
        }
    }

    private var storeSearchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(searchFocused ? accent : Color.secondary)

            TextField(
                kind == .theme ? "Search all themes" : "Search all extensions",
                text: $query
            )
            .textFieldStyle(.plain)
            .font(.body)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            .keyboardType(.webSearch)
            #endif
            .autocorrectionDisabled()
            .submitLabel(.search)
            .focused($searchFocused)

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
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            OrielTheme.elevatedFill(for: colorScheme),
            in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                .strokeBorder(
                    searchFocused ? accent.opacity(0.45) : OrielTheme.hairline(for: colorScheme),
                    lineWidth: searchFocused ? 1.5 : 1
                )
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { item in
                    Button {
                        category = item
                    } label: {
                        Label(item.title, systemImage: item.systemImage)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                item.id == category.id
                                    ? accent.opacity(0.18)
                                    : Color.primary.opacity(0.05),
                                in: Capsule(style: .continuous)
                            )
                            .foregroundStyle(item.id == category.id ? accent : Color.primary.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item.id == category.id ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private var catalogSection: some View {
        if isLoading && listings.isEmpty {
            Section {
                HStack {
                    Spacer()
                    ProgressView("Loading catalog…")
                        .padding(.vertical, 28)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
        } else if let errorMessage, listings.isEmpty {
            Section {
                ContentUnavailableView(
                    "Couldn’t load store",
                    systemImage: "wifi.exclamationmark",
                    description: Text(errorMessage)
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)

                Button("Retry") {
                    Task { await reload(debounce: false, reset: true) }
                }
                .foregroundStyle(accent)
            }
        } else if listings.isEmpty {
            Section {
                ContentUnavailableView(
                    "No results",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Try another category or search across Chrome, Firefox, and Safari.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
        } else {
            Section {
                ForEach(listings) { listing in
                    NavigationLink {
                        OrielStoreDetailView(listing: listing)
                    } label: {
                        storeRow(listing)
                    }
                }

                if canLoadMore {
                    Button {
                        Task { await loadMore() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoadingMore {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading more…")
                                    .font(.subheadline.weight(.medium))
                            } else {
                                Text("Load more")
                                    .font(.subheadline.weight(.semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(isLoadingMore)
                    .foregroundStyle(accent)
                }
            } header: {
                Text(sectionTitle)
            } footer: {
                Text("Browsing Chrome Web Store and Firefox Add-ons. Open a listing for screenshots and the full description.")
            }
        }
    }

    private var sectionTitle: String {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Results · \(sort.title)"
        }
        return "\(category.title) · \(sort.title)"
    }

    private var footerBlurb: String {
        "Browse by category or search the full Chrome and Firefox catalogs. Open a listing for the full description — Oriel picks the best source when you install."
    }

    private func storeRow(_ listing: UnifiedStoreListing) -> some View {
        let report = ExtensionCompatibility.assess(listing)
        let installed = installedSource(for: listing)
        return HStack(alignment: .center, spacing: 12) {
            iconView(for: listing)

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !listing.summary.isEmpty {
                    Text(listing.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    compatBadge(report.level)
                    Text(metaLine(for: listing, report: report, installed: installed))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Shows description and screenshots")
    }

    private func metaLine(
        for listing: UnifiedStoreListing,
        report: ExtensionCompatReport,
        installed: ExtensionStoreItem.Source?
    ) -> String {
        if let installed {
            return installed.installedFromLabel
        }
        var parts: [String] = []
        let sources = listing.availableSources.map(\.displayName)
        if !sources.isEmpty {
            parts.append(sources.joined(separator: " · "))
        }
        parts.append("\(report.score.percent)% Oriel")
        if let rating = listing.rating {
            parts.append(String(format: "%.1f★", rating))
        }
        return parts.joined(separator: " · ")
    }

    private func compatBadge(_ level: ExtensionCompatLevel) -> some View {
        let color: Color = {
            switch level {
            case .full: return .green
            case .partial: return .orange
            case .unsupported: return .red
            }
        }()
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            Text(level.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
        .accessibilityLabel(level.accessibilityLabel)
    }

    @ViewBuilder
    private func iconView(for listing: UnifiedStoreListing) -> some View {
        let shape = RoundedRectangle(cornerRadius: OrielTheme.chromeButtonRadius, style: .continuous)
        let placeholder = Image(systemName: listing.kind == .theme ? "paintpalette.fill" : "puzzlepiece.extension.fill")
            .font(.title3)
            .foregroundStyle(accent.opacity(0.85))
            .frame(width: 44, height: 44)
            .background(accent.opacity(0.12), in: shape)

        if let url = listing.iconURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(shape)
                        .overlay {
                            shape.strokeBorder(OrielTheme.hairline(for: colorScheme), lineWidth: 1)
                        }
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private func installedSource(for listing: UnifiedStoreListing) -> ExtensionStoreItem.Source? {
        for offer in listing.offers {
            switch offer.source {
            case .chrome:
                if environment.extensions.isInstalledFromChromeWebStore(extensionID: offer.storeIdentifier) {
                    return .chrome
                }
            case .firefox:
                if environment.extensions.isInstalledFromFirefoxAMO(slug: offer.storeIdentifier) {
                    return .firefox
                }
            case .safari:
                if environment.extensions.isInstalledFromSafari(bundleIdentifier: offer.storeIdentifier) {
                    return .safari
                }
            }
        }
        let key = ExtensionStoreCatalog.normalizationKey(forName: listing.name)
        if environment.extensions.extensions.contains(where: {
            ExtensionStoreCatalog.normalizationKey(forName: $0.displayName) == key
                && $0.chromeStoreID == nil
                && $0.firefoxSlug == nil
        }) {
            return listing.offers.contains(where: { $0.source == .safari }) ? .safari : listing.offers.first?.source
        }
        return nil
    }

    private func offerToInstall(for listing: UnifiedStoreListing) -> ExtensionStoreItem? {
        if let installed = installedSource(for: listing),
           let offer = listing.offers.first(where: { $0.source == installed }) {
            return offer
        }
        if let preferred = listing.preferredOffer {
            if preferred.source == .safari, preferred.storeIdentifier.hasPrefix("known:") {
                return listing.offers.first(where: { $0.source != .safari })
            }
            return preferred
        }
        return listing.offers.first
    }

    private func requestInstall(_ listing: UnifiedStoreListing) {
        if installedSource(for: listing) != nil {
            dismiss()
            environment.showExtensions = true
            return
        }
        let report = ExtensionCompatibility.assess(listing)
        if report.shouldWarnBeforeInstall {
            pendingCompatInstall = listing
            showCompatWarning = true
            return
        }
        Task { await performInstall(listing) }
    }

    @MainActor
    private func reload(debounce: Bool, reset: Bool) async {
        if reset {
            page = 1
            canLoadMore = true
            if !debounce {
                isLoading = true
                listings = []
            }
        }
        errorMessage = nil
        let requestedKind = kind
        let requestedQuery = query
        let requestedCategory = category
        let requestedSort = sort
        let requestedPage = page
        let safari = environment.extensions.safariCandidates
        let result = await ExtensionStoreCatalog.searchUniversal(
            query: requestedQuery,
            kind: requestedKind,
            limit: ExtensionStoreCatalog.defaultPageSize,
            page: requestedPage,
            category: requestedCategory,
            sort: requestedSort,
            safariCandidates: safari
        )
        guard !Task.isCancelled else { return }
        guard requestedKind == kind,
              requestedQuery == query,
              requestedCategory.id == category.id,
              requestedSort == sort,
              requestedPage == page else { return }

        if reset || page == 1 {
            listings = result
        } else {
            let existing = Set(listings.map(\.id))
            let appended = result.filter { !existing.contains($0.id) }
            listings.append(contentsOf: appended)
        }
        canLoadMore = result.count >= max(20, ExtensionStoreCatalog.defaultPageSize / 3)
        if result.isEmpty && requestedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && page == 1 {
            errorMessage = "Couldn’t load the catalog. Check your connection and try again."
        } else {
            errorMessage = nil
        }
        isLoading = false
        isLoadingMore = false
    }

    @MainActor
    private func loadMore() async {
        guard canLoadMore, !isLoadingMore, !isLoading else { return }
        isLoadingMore = true
        page += 1
        await reload(debounce: true, reset: false)
    }

    @MainActor
    private func performInstall(_ listing: UnifiedStoreListing) async {
        guard let offer = offerToInstall(for: listing) else {
            installError = "No installable source found for this extension."
            return
        }
        installingID = listing.id
        installError = nil
        installStatus = "Starting install from \(offer.source.displayName)…"
        defer { installingID = nil }

        await install(offer: offer)

        if environment.extensions.lastError != nil {
            let fallback = listing.offers.first(where: {
                $0.id != offer.id && ($0.source == .chrome || $0.source == .firefox)
            })
            if let fallback {
                installStatus = "Retrying from \(fallback.source.displayName)…"
                await install(offer: fallback)
            }
        }

        if let err = environment.extensions.lastError {
            installError = err
            installStatus = nil
        } else if installHint != nil {
            installStatus = nil
        } else {
            ExtensionCompatibility.recordLocalInstall(listingID: listing.id)
            installStatus = environment.extensions.statusMessage ?? "Installed “\(listing.name)”."
        }
    }

    @MainActor
    private func install(offer: ExtensionStoreItem) async {
        switch offer.source {
        case .chrome:
            await environment.extensions.installFromChromeWebStore(extensionID: offer.storeIdentifier)
        case .firefox:
            await environment.extensions.installFromFirefoxAMO(slugOrID: offer.storeIdentifier)
        case .safari:
            if offer.storeIdentifier.hasPrefix("known:") {
                installHint =
                    "This extension is also published for Safari. On Mac, install its Safari app, then use Extensions → Scan Safari extensions to import it into Oriel."
            } else if let candidate = environment.extensions.safariCandidates.first(where: {
                $0.bundleIdentifier == offer.storeIdentifier
            }) {
                await environment.extensions.installSafariCandidate(candidate)
            } else if let url = offer.storeURL {
                await environment.extensions.installFromPackage(at: url)
            } else {
                installHint = "That Safari extension isn’t available to import on this device yet."
            }
        }
    }
}
