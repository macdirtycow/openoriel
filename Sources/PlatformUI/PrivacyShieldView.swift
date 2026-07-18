import SwiftUI

/// Privacy / Shields sheet — readable on iPhone, iPad, and Mac.
struct PrivacyShieldView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isClearing = false
    @State private var clearMessage: String?

    private var host: String? {
        let value = environment.activeTab?.navigation.url?.host
        guard let value, !URLParser.isStartPage(environment.activeTab?.navigation.url) else {
            return nil
        }
        return value
    }

    private var siteSettings: SiteShieldSettings {
        environment.privacy.settings(forHost: host)
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        NavigationStack {
            List {
                dashboardSection
                globalShieldsSection
                if let host {
                    siteSection(host: host)
                    permissionsSection(host: host)
                }
                privateSection
                dataSection
                statusSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            .frame(minWidth: 420)
            #endif
            .navigationTitle("Shields")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(iOS)
        .presentationDetents(isCompact ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationContentInteraction(.scrolls)
        #endif
    }

    // MARK: - Sections

    private var dashboardSection: some View {
        Section {
            statRow(
                title: "Blocked this session",
                value: "\(environment.privacyStats.blockedRequestsSession)",
                systemImage: "hand.raised.fill"
            )
            statRow(
                title: "HTTPS upgrades",
                value: "\(environment.privacyStats.httpsUpgradesSession)",
                systemImage: "lock.rotation"
            )
            statRow(
                title: "Blocked all time",
                value: "\(environment.privacyStats.blockedRequestsLifetime)",
                systemImage: "chart.bar.fill"
            )
        } header: {
            Text("Dashboard")
        } footer: {
            Text("Counts are best-effort. WebKit does not expose a full blocker hit log.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var globalShieldsSection: some View {
        @Bindable var privacy = environment.privacy
        return Section {
            Toggle(isOn: $privacy.contentBlockingEnabled) {
                labeledToggle(
                    "Block trackers & ads",
                    subtitle: "EasyList + EasyPrivacy network rules, plus YouTube ad blocking"
                )
            }
            Toggle(isOn: $privacy.httpsUpgradeEnabled) {
                labeledToggle("HTTPS upgrades", subtitle: "Prefer https when it looks safe")
            }
            Toggle(isOn: $privacy.blockThirdPartyCookies) {
                labeledToggle(
                    "Limit third-party cookies",
                    subtitle: "May break Google Account and other sign-in flows; leave off to stay signed in"
                )
            }
        } header: {
            Text("Global shields")
        } footer: {
            Text("Shields use Apple’s content blocker engine (like Safari). Most web ads and many YouTube ads are blocked; some first-party YouTube streams can still slip through.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func siteSection(host: String) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { siteSettings.contentBlockingEnabled },
                set: { environment.privacy.setContentBlocking($0, forHost: host) }
            )) {
                labeledToggle("Content blocking", subtitle: host)
            }
            Toggle(isOn: Binding(
                get: { siteSettings.httpsUpgradeEnabled },
                set: { environment.privacy.setHTTPSUpgrade($0, forHost: host) }
            )) {
                labeledToggle("HTTPS upgrade", subtitle: host)
            }
        } header: {
            Text("This site")
        }
    }

    private func permissionsSection(host: String) -> some View {
        Section {
            ForEach(SitePermission.allCases) { permission in
                VStack(alignment: .leading, spacing: 8) {
                    Label(permission.displayName, systemImage: permission.systemImage)
                        .font(.body.weight(.medium))
                    Picker(
                        "Decision",
                        selection: Binding(
                            get: { environment.permissions.decision(for: host, permission: permission) },
                            set: { environment.permissions.setDecision($0, for: host, permission: permission) }
                        )
                    ) {
                        Text("Ask").tag(PermissionDecision.ask)
                        Text("Allow").tag(PermissionDecision.allow)
                        Text("Deny").tag(PermissionDecision.deny)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("\(permission.displayName) permission")
                }
                .padding(.vertical, 4)
            }

            let granted = environment.permissions.grantedPermissions(for: host)
            if !granted.isEmpty {
                Text("Currently allowed: " + granted.map(\.displayName).joined(separator: ", "))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Permissions")
        } footer: {
            Text("Applies when \(host) asks for camera, microphone, or location.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var privateSection: some View {
        Section {
            Button {
                environment.tabs.createPrivateTab(select: true)
                environment.wireTabPrivacyHooks()
                dismiss()
            } label: {
                Label("Open Private Tab", systemImage: "eyeglasses")
            }
        } header: {
            Text("Private browsing")
        } footer: {
            Text("Private tabs use a temporary data store and are not saved to history or session restore.")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) {
                Task { await clearData() }
            } label: {
                if isClearing {
                    HStack {
                        ProgressView()
                        Text("Clearing…")
                    }
                } else {
                    Label("Clear Cookies & Website Data", systemImage: "trash")
                }
            }
            .disabled(isClearing)

            if let clearMessage {
                Text(clearMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } header: {
            Text("Browsing data")
        }
    }

    private var statusSection: some View {
        Section {
            HStack {
                Text("Filter rules")
                Spacer()
                Text("\(environment.contentBlocker.ruleCount)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)

            if !environment.contentBlocker.listNames.isEmpty {
                Text(environment.contentBlocker.listNames.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = environment.contentBlocker.lastError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(environment.contentBlocker.isReady ? "Content blocker ready" : "Compiling rules…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Status")
        }
    }

    // MARK: - Helpers

    private func statRow(title: String, value: String, systemImage: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, alignment: .center)
                .accessibilityHidden(true)

            Text(title)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .accessibilityLabel(value)
        }
        .accessibilityElement(children: .combine)
        .padding(.vertical, 2)
    }

    private func labeledToggle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func clearData() async {
        isClearing = true
        clearMessage = nil
        await WebsiteDataCleaner.clearBrowsingData()
        clearMessage = "Cleared cookies and website data from the default store."
        isClearing = false
    }
}
