import SwiftUI

#if os(macOS)
/// Mac Chromium dual-engine features — site list, identity inject, hand-off.
struct ChromiumFeaturesView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton: Bool = true

    var body: some View {
        if showsDoneButton {
            NavigationStack {
                formContent
                    .navigationTitle("Chromium on Mac")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
            .frame(minWidth: 440, minHeight: 420)
        } else {
            formContent
                .navigationTitle("Chromium on Mac")
        }
    }

    private var formContent: some View {
        @Bindable var policy = environment.chromiumPolicy
        return Form {
            Section {
                Text("Smart (default) picks per tab: WebKit for Apple/captcha hosts; Chromium Native (real Blink) for stubborn apps when CEF or system Chrome is available; Chromium Compatible (WebKit + Chrome identity) as fallback. Classic and Pulse share these controls.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                ForEach(BrowserEngineKind.availableOnThisPlatform) { engine in
                    Button {
                        environment.settings.preferredEngine = engine
                        environment.syncPulseRuntimeFlags()
                        environment.icloudSync.noteLocalChange()
                        environment.activeTab?.reload()
                    } label: {
                        HStack {
                            Label(engine.displayName, systemImage: engine.systemImage)
                            Spacer()
                            if environment.settings.preferredEngine == engine {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(environment.settings.brandColor)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                Text("Default page engine")
            }

            Section {
                Toggle("Smart prefers Native / Blink for stubborn sites", isOn: $policy.smartPrefersNativeBlink)
                Toggle("Auto-upgrade stubborn sites when default is WebKit", isOn: $policy.autoChromiumForStubbornSites)
                Toggle("Inject Chrome Client Hints (userAgentData)", isOn: $policy.injectChromeIdentity)
                Toggle("Suggest Open in system Chrome for stubborn sites", isOn: $policy.suggestSystemChromeForStubbornSites)
            } header: {
                Text("Smart & Chromium extras")
            } footer: {
                Text("Smart uses Native/Blink when possible (in-tab CEF or managed Chrome). Netflix/Discord/Meet prefer real Blink; other stubborn hosts follow the Smart Native toggle. Compatible remains WebKit + Chrome identity — not Blink.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let host = currentHost {
                Section {
                    Picker("Engine for this site", selection: Binding(
                        get: { policy.preference(forHost: host) },
                        set: {
                            policy.setPreference($0, forHost: host)
                            environment.applyResolvedEngine(to: environment.activeTab)
                            environment.activeTab?.reload()
                        }
                    )) {
                        ForEach(ChromiumHostPreference.allCases) { pref in
                            Text(pref.displayName).tag(pref)
                        }
                    }
                    if ChromiumEngineBridge.systemChromiumInstalled,
                       let url = environment.activeTab?.navigation.url {
                        Button("Open current page in system Chrome…") {
                            _ = ChromiumEngineBridge.openInSystemChromium(url)
                        }
                    }
                } header: {
                    Text(host)
                }
            }

            if !policy.sortedHostOverrides.isEmpty {
                Section {
                    ForEach(policy.sortedHostOverrides, id: \.host) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.host)
                                Text(item.preference.displayName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Reset") {
                                policy.setPreference(.followDefault, forHost: item.host)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button("Clear all site overrides", role: .destructive) {
                        policy.clearAllHostPreferences()
                        environment.syncPulseRuntimeFlags()
                    }
                } header: {
                    Text("Site overrides")
                }
            }

            Section {
                Text("Built-in auto list includes \(ChromiumAutoSiteList.stubbornDesktopHosts.count) hosts (Meet, Teams, Discord, Netflix, Docs, …). \(ChromiumAutoSiteList.realBlinkPreferredHosts.count) of those prefer real Blink when Native is available.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(ChromiumNativeHost.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if ChromiumEngineBridge.systemChromiumInstalled {
                    Text("System Chromium detected: \(ChromiumEngineBridge.preferredSystemChromiumName ?? "Chrome")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No system Chrome/Chromium/Arc found — install one for Native hand-off.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                Button("Mac Governors…") {
                    environment.showMacGovernors = true
                }
            } header: {
                Text("Status")
            }
        }
        .formStyle(.grouped)
    }

    private var currentHost: String? {
        guard let url = environment.activeTab?.navigation.url,
              !URLParser.isStartPage(url),
              let host = url.host, !host.isEmpty else { return nil }
        return host
    }
}
#endif
