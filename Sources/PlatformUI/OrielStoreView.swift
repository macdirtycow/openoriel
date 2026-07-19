import SwiftUI

/// Native extension/theme browser backed by Chrome Web Store + Firefox AMO catalogs.
/// Preferred over opening the store websites (iPhone, iPad, and Mac).
struct OrielStoreView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var source: ExtensionStoreItem.Source = .chrome
    @State private var kind: ExtensionStoreItem.Kind = .extension
    @State private var query = ""
    @State private var items: [ExtensionStoreItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var installingID: String?
    @State private var searchTask: Task<Void, Never>?

    /// When true (sheet presentation), show a Done button. Hidden inside Extensions navigation.
    var showsDoneButton: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            pickerBar
            searchField
            content
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
        .task(id: "\(source.rawValue)-\(kind.rawValue)") {
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
    }

    private var pickerBar: some View {
        VStack(spacing: 10) {
            Picker("Source", selection: $source) {
                Text("Chrome").tag(ExtensionStoreItem.Source.chrome)
                Text("Firefox").tag(ExtensionStoreItem.Source.firefox)
            }
            .pickerStyle(.segmented)

            Picker("Kind", selection: $kind) {
                Text("Extensions").tag(ExtensionStoreItem.Kind.extension)
                Text("Themes").tag(ExtensionStoreItem.Kind.theme)
            }
            .pickerStyle(.segmented)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField(searchPlaceholder, text: $query)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.webSearch)
                #endif
                .autocorrectionDisabled()
                .submitLabel(.search)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var searchPlaceholder: String {
        switch (source, kind) {
        case (.chrome, .extension): return "Search Chrome extensions"
        case (.chrome, .theme): return "Search Chrome themes"
        case (.firefox, .extension): return "Search Firefox add-ons"
        case (.firefox, .theme): return "Search Firefox themes"
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading && items.isEmpty {
            Spacer()
            ProgressView("Loading catalog…")
            Spacer()
        } else if let errorMessage, items.isEmpty {
            Spacer()
            ContentUnavailableView(
                "Couldn’t load store",
                systemImage: "wifi.exclamationmark",
                description: Text(errorMessage)
            )
            Button("Retry") {
                Task { await reload(debounce: false) }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        } else if items.isEmpty {
            Spacer()
            ContentUnavailableView(
                "No results",
                systemImage: "puzzlepiece.extension",
                description: Text("Try another search, or switch between Chrome and Firefox.")
            )
            Spacer()
        } else {
            List {
                Section {
                    Text(footerBlurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                }

                Section {
                    ForEach(items) { item in
                        storeRow(item)
                    }
                } header: {
                    Text(query.isEmpty ? "Popular" : "Results")
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #endif
        }
    }

    private var footerBlurb: String {
        "Oriel Store loads Chrome and Firefox catalogs in a readable list on Mac, iPhone, and iPad. Install uses the same CRX/XPI pipeline as Add to Oriel."
    }

    private func storeRow(_ item: ExtensionStoreItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            iconView(for: item)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if !item.summary.isEmpty {
                    Text(item.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                HStack(spacing: 8) {
                    Text(item.source == .chrome ? "Chrome" : "Firefox")
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.12), in: Capsule())
                    if let rating = item.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if isInstalled(item) {
                        Text("Installed")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.green)
                    }
                }
            }
            Spacer(minLength: 0)
            Button {
                Task { await install(item) }
            } label: {
                if installingID == item.id || environment.extensions.isInstallingFromStore {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text(isInstalled(item) ? "Open" : "Add")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(installingID != nil || environment.extensions.isInstallingFromStore)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func iconView(for item: ExtensionStoreItem) -> some View {
        let placeholder = Image(systemName: item.kind == .theme ? "paintpalette.fill" : "puzzlepiece.extension.fill")
            .font(.title3)
            .foregroundStyle(.secondary)
            .frame(width: 44, height: 44)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        if let url = item.iconURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private func isInstalled(_ item: ExtensionStoreItem) -> Bool {
        switch item.source {
        case .chrome:
            return environment.extensions.isInstalledFromChromeWebStore(extensionID: item.storeIdentifier)
        case .firefox:
            return environment.extensions.isInstalledFromFirefoxAMO(slug: item.storeIdentifier)
        }
    }

    @MainActor
    private func reload(debounce: Bool) async {
        if !debounce {
            isLoading = true
        }
        errorMessage = nil
        let requestedSource = source
        let requestedKind = kind
        let requestedQuery = query
        do {
            let result = try await ExtensionStoreCatalog.search(
                query: requestedQuery,
                source: requestedSource,
                kind: requestedKind,
                limit: 40
            )
            guard !Task.isCancelled else { return }
            // Drop stale responses if the user switched tabs mid-flight.
            guard requestedSource == source, requestedKind == kind, requestedQuery == query else { return }
            items = result
            isLoading = false
        } catch is CancellationError {
            // Keep previous items; a newer task owns loading state.
        } catch {
            guard !Task.isCancelled else { return }
            guard requestedSource == source, requestedKind == kind, requestedQuery == query else { return }
            // Last resort: curated list so the store is never a blank screen.
            let fallback = ExtensionStoreCatalog.curatedFallback(
                source: requestedSource,
                kind: requestedKind,
                query: requestedQuery
            )
            if fallback.isEmpty {
                items = []
                errorMessage = "Couldn’t load the catalog. Check your connection and try again."
            } else {
                items = fallback
                errorMessage = nil
            }
            isLoading = false
        }
    }

    @MainActor
    private func install(_ item: ExtensionStoreItem) async {
        if isInstalled(item) {
            dismiss()
            environment.showExtensions = true
            return
        }
        installingID = item.id
        defer { installingID = nil }
        switch item.source {
        case .chrome:
            await environment.extensions.installFromChromeWebStore(extensionID: item.storeIdentifier)
        case .firefox:
            await environment.extensions.installFromFirefoxAMO(slugOrID: item.storeIdentifier)
        }
        // Refresh installed badges.
        items = items
    }
}
