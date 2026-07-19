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
                Text("Oriel still paints with WebKit. Smart mode picks WebKit or Chromium Compatible per tab from the page. Chromium Compatible adds Chrome’s desktop identity (UA + Client Hints). Chromium Native needs a linked CEF framework later. Classic and Pulse share these controls.")
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
                Toggle("Auto Chromium Compatible for stubborn sites", isOn: $policy.autoChromiumForStubbornSites)
                Toggle("Inject Chrome Client Hints (userAgentData)", isOn: $policy.injectChromeIdentity)
                Toggle("Suggest Open in system Chrome for stubborn sites", isOn: $policy.suggestSystemChromeForStubbornSites)
            } header: {
                Text("Chromium Compatible extras")
            } footer: {
                Text("Auto mode only upgrades hosts on the built-in list (Meet, Teams, Discord, Docs, …) when your default is WebKit. Client Hints help sites that ignore UA alone.")
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
                Text("Built-in auto list includes \(ChromiumAutoSiteList.stubbornDesktopHosts.count) hosts (Google Meet, Microsoft Teams, Discord, Notion, Figma, Office web apps, …).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if ChromiumEngineBridge.systemChromiumInstalled {
                    Text("System Chromium detected: \(ChromiumEngineBridge.preferredSystemChromiumName ?? "Chrome")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No system Chrome/Chromium/Arc found — install one for hand-off.")
                        .font(.caption)
                        .foregroundStyle(.orange)
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
