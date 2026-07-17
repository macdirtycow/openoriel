import SwiftUI

struct PrivacyShieldView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var isClearing = false
    @State private var clearMessage: String?

    private var host: String? {
        environment.activeTab?.navigation.url?.host
    }

    private var siteSettings: SiteShieldSettings {
        environment.privacy.settings(forHost: host)
    }

    var body: some View {
        @Bindable var privacy = environment.privacy
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Blocked this session", value: "\(environment.privacyStats.blockedRequestsSession)")
                    LabeledContent("HTTPS upgrades", value: "\(environment.privacyStats.httpsUpgradesSession)")
                    LabeledContent("Blocked (all time)", value: "\(environment.privacyStats.blockedRequestsLifetime)")
                } header: {
                    Text("Privacy dashboard")
                } footer: {
                    Text("Blocked counts are best-effort. WebKit does not expose a full hit log for in-app content rules. See PRIVACY_LIMITATIONS.md.")
                }

                Section("Shields") {
                    Toggle("Block trackers & ads", isOn: $privacy.contentBlockingEnabled)
                    Toggle("Upgrade connections to HTTPS", isOn: $privacy.httpsUpgradeEnabled)
                    Toggle("Prefer blocking third-party cookies", isOn: $privacy.blockThirdPartyCookies)
                }

                if let host {
                    Section("This site (\(host))") {
                        Toggle("Content blocking", isOn: Binding(
                            get: { siteSettings.contentBlockingEnabled },
                            set: { environment.privacy.setContentBlocking($0, forHost: host) }
                        ))
                        Toggle("HTTPS upgrade", isOn: Binding(
                            get: { siteSettings.httpsUpgradeEnabled },
                            set: { environment.privacy.setHTTPSUpgrade($0, forHost: host) }
                        ))
                    }
                }

                Section("Private browsing") {
                    Button("New Private Tab") {
                        environment.tabs.createPrivateTab(select: true)
                        dismiss()
                    }
                    Text("Private tabs use a non-persistent data store and are not saved to history or session restore.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Browsing data") {
                    Button("Clear Cookies & Website Data", role: .destructive) {
                        Task { await clearData() }
                    }
                    .disabled(isClearing)
                    if let clearMessage {
                        Text(clearMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Status") {
                    LabeledContent("Filter rules", value: "\(environment.contentBlocker.ruleCount)")
                    if let error = environment.contentBlocker.lastError {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(.orange)
                    } else {
                        Text(environment.contentBlocker.isReady ? "Content blocker ready" : "Compiling…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
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
    }

    private func clearData() async {
        isClearing = true
        clearMessage = nil
        await WebsiteDataCleaner.clearBrowsingData()
        clearMessage = "Cleared cookies and website data from the default store."
        isClearing = false
    }
}
