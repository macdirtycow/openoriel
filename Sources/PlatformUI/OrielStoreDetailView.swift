import SwiftUI

/// Product page for one store listing — description, screenshots, compat, install.
/// Shared across iPhone, iPad, and Mac.
struct OrielStoreDetailView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL

    let listing: UnifiedStoreListing

    @State private var detail: StoreProductDetail?
    @State private var isLoading = true
    @State private var loadError: String?
    @State private var installing = false
    @State private var installHint: String?
    @State private var pendingCompatInstall = false
    @State private var showPermissionReview = false
    @State private var installError: String?
    @State private var installStatus: String?

    private var accent: Color { environment.settings.brandColor }
    private var report: ExtensionCompatReport { ExtensionCompatibility.assess(listing) }
    private var installed: ExtensionStoreItem.Source? { installedSource(for: listing) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                if !screenshots.isEmpty {
                    screenshotStrip
                }
                aboutSection
                sourcesSection
                if !permissions.isEmpty {
                    permissionsSection
                }
                installFooter
                if let installStatus {
                    Label(installStatus, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(accent)
                        .symbolRenderingMode(.hierarchical)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .navigationTitle(listing.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                installToolbarButton
            }
        }
        .task(id: listing.id) {
            await loadDetail()
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
            isPresented: $pendingCompatInstall,
            titleVisibility: .visible
        ) {
            Button("Review & install") {
                showPermissionReview = true
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(report.installWarning)
        }
        .sheet(isPresented: $showPermissionReview) {
            let declared = permissions
            let hosts = declared.filter { $0.contains("://") || $0 == "<all_urls>" || $0.hasPrefix("*://") }
            ExtensionPermissionReviewView(
                extensionName: listing.name,
                permissions: declared.filter { !($0.contains("://") || $0 == "<all_urls>" || $0.hasPrefix("*://")) },
                hostPatterns: hosts,
                onConfirm: { allowed in
                    let offer = offerToInstall(for: listing)
                    environment.extensions.prepareInstallPermissionReview(
                        allowed: allowed,
                        directoryHint: offer?.storeIdentifier
                    )
                    showPermissionReview = false
                    Task { await performInstall() }
                },
                onCancel: {
                    environment.extensions.clearPendingPermissionReview()
                    showPermissionReview = false
                }
            )
        }
    }

    private var screenshots: [URL] {
        detail?.screenshotURLs ?? []
    }

    private var permissions: [String] {
        let fromDetail = detail?.permissions ?? []
        if !fromDetail.isEmpty { return fromDetail }
        return listing.preferredOffer?.permissions ?? []
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            iconView
            VStack(alignment: .leading, spacing: 6) {
                Text(detail?.name ?? listing.name)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                if let author = detail?.authorName, !author.isEmpty {
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    compatBadge(report.level)
                    if let rating = detail?.rating ?? listing.rating {
                        Label(String(format: "%.1f", rating), systemImage: "star.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    if let users = detail?.userCount {
                        Text("\(formattedCount(users)) users")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if let version = detail?.version {
                    Text("Version \(version)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var screenshotStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(screenshots.enumerated()), id: \.offset) { _, url in
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                                .fill(Color.secondary.opacity(0.12))
                                .overlay { ProgressView().controlSize(.small) }
                        }
                    }
                    .frame(width: 260, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                            .strokeBorder(OrielTheme.hairline(for: colorScheme), lineWidth: 1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityLabel("Screenshots")
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("About")
                .font(.headline)
            if isLoading && detail == nil {
                ProgressView("Loading description…")
                    .controlSize(.small)
            } else if let loadError, detail == nil {
                Text(loadError)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                let summary = detail?.summary ?? listing.summary
                if !summary.isEmpty {
                    Text(summary)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                }
                let body = detail?.description ?? listing.summary
                if !body.isEmpty, body != summary {
                    Text(body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else if summary.isEmpty {
                    Text("No description available.")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }
            if let homepage = detail?.homepageURL {
                Link("Developer site", destination: homepage)
                    .font(.subheadline.weight(.semibold))
            }
            if let storeURL = detail?.storeURL ?? listing.preferredOffer?.storeURL {
                Button {
                    openURL(storeURL)
                } label: {
                    Label(
                        "View on \(detail?.primarySource.displayName ?? listing.preferredOffer?.source.displayName ?? "store")",
                        systemImage: "safari"
                    )
                    .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(accent)
            }
        }
    }

    private var sourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.headline)
            ForEach(listing.offers, id: \.id) { offer in
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accent)
                    Text(offer.source.displayName)
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.headline)
            Text(permissions.prefix(12).joined(separator: ", "))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if permissions.count > 12 {
                Text("\(permissions.count - 12) more")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var installFooter: some View {
        Button {
            requestInstall()
        } label: {
            if installing || environment.extensions.isInstallingFromStore {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            } else {
                Text(installed != nil ? "Open Extensions" : "Add to Oriel")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .disabled(installing || environment.extensions.isInstallingFromStore)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var installToolbarButton: some View {
        Button {
            requestInstall()
        } label: {
            if installing || environment.extensions.isInstallingFromStore {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(installed != nil ? "Open" : "Add")
                    .fontWeight(.semibold)
            }
        }
        .disabled(installing || environment.extensions.isInstallingFromStore)
    }

    private var iconView: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        let placeholder = Image(systemName: listing.kind == .theme ? "paintpalette.fill" : "puzzlepiece.extension.fill")
            .font(.title)
            .foregroundStyle(accent.opacity(0.85))
            .frame(width: 72, height: 72)
            .background(accent.opacity(0.12), in: shape)

        return Group {
            if let url = detail?.iconURL ?? listing.iconURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: 72, height: 72)
                            .clipShape(shape)
                            .overlay { shape.strokeBorder(OrielTheme.hairline(for: colorScheme), lineWidth: 1) }
                    default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
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
            Circle().fill(color).frame(width: 7, height: 7)
            Text(level.title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func formattedCount(_ n: Int) -> String {
        if n >= 1_000_000 {
            return String(format: "%.1fM", Double(n) / 1_000_000.0)
        }
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000.0)
        }
        return "\(n)"
    }

    @MainActor
    private func loadDetail() async {
        isLoading = true
        loadError = nil
        let result = await ExtensionStoreCatalog.fetchProductDetail(for: listing)
        detail = result
        if result.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && result.summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            loadError = "Description unavailable. You can still install from the listed sources."
        }
        isLoading = false
    }

    private func requestInstall() {
        if installed != nil {
            environment.showExtensions = true
            return
        }
        if report.shouldWarnBeforeInstall {
            pendingCompatInstall = true
            return
        }
        showPermissionReview = true
    }

    @MainActor
    private func performInstall() async {
        guard let offer = offerToInstall(for: listing) else {
            installError = "No installable source found for this extension."
            return
        }
        installing = true
        installError = nil
        installStatus = "Starting install from \(offer.source.displayName)…"
        defer { installing = false }

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
        return nil
    }
}

