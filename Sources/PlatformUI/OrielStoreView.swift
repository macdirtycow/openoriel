import SwiftUI

/// Universal extension/theme browser — one search across Chrome, Firefox, and Safari.
/// Preferred over opening the store websites (iPhone, iPad, and Mac).
struct OrielStoreView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var kind: ExtensionStoreItem.Kind = .extension
    @State private var query = ""
    @State private var listings: [UnifiedStoreListing] = []
    @State private var isLoading = false
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
        }
        .task(id: kind.rawValue) {
            await reload(debounce: false)
        }
        .onChange(of: query) { _, _ in
            searchTask?.cancel()
            searchTask = Task {
                try? await Task.sleep(nanoseconds: 350_000_000)
                guard !Task.isCancelled else { return }
                await reload(debounce: true)
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
        // `presenting:` passes a stable copy into actions — avoids the SwiftUI alert bug
        // where clearing the optional binding wiped the listing before Install ran.
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
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 10, trailing: 16))
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
                kind == .theme ? "Search themes" : "Search extensions",
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
                    Task { await reload(debounce: false) }
                }
                .foregroundStyle(accent)
            }
        } else if listings.isEmpty {
            Section {
                ContentUnavailableView(
                    "No results",
                    systemImage: "puzzlepiece.extension",
                    description: Text("Try another search across Chrome, Firefox, and Safari.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }
        } else {
            Section {
                ForEach(listings) { listing in
                    storeRow(listing)
                }
            } header: {
                Text(query.isEmpty ? "Popular" : "Results")
            }
        }
    }

    private var footerBlurb: String {
        "One catalog for Chrome, Firefox, and Safari. Compatibility reflects WebKit limits — Oriel picks the best source when you tap Add."
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

            Spacer(minLength: 8)

            Button {
                requestInstall(listing)
            } label: {
                if installingID == listing.id || environment.extensions.isInstallingFromStore {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 52)
                } else {
                    Text(installed != nil ? "Open" : "Add")
                        .font(.subheadline.weight(.semibold))
                        .frame(minWidth: 52)
                }
            }
            .buttonStyle(.bordered)
            .tint(accent)
            .controlSize(.small)
            .disabled(installingID != nil || environment.extensions.isInstallingFromStore)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
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
    private func reload(debounce: Bool) async {
        if !debounce {
            isLoading = true
        }
        errorMessage = nil
        let requestedKind = kind
        let requestedQuery = query
        let safari = environment.extensions.safariCandidates
        let result = await ExtensionStoreCatalog.searchUniversal(
            query: requestedQuery,
            kind: requestedKind,
            limit: 40,
            safariCandidates: safari
        )
        guard !Task.isCancelled else { return }
        guard requestedKind == kind, requestedQuery == query else { return }
        listings = result
        if result.isEmpty && requestedQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Couldn’t load the catalog. Check your connection and try again."
        } else {
            errorMessage = nil
        }
        isLoading = false
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

        // If the preferred source failed, try the next Chrome/Firefox offer once.
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
