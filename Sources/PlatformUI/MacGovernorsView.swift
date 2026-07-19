import SwiftUI

/// Mac CPU / RAM governors + Chromium Native status (Classic and Pulse).
struct MacGovernorsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    var showsDoneButton: Bool = true

    private var governor: MacPerformanceGovernor { environment.macGovernors }

    var body: some View {
        Group {
            if showsDoneButton {
                NavigationStack {
                    formContent
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }
            } else {
                formContent
            }
        }
    }

    private var formContent: some View {
        Form {
            Section {
                Text("These governors act on Oriel’s WebKit tabs (timer throttle + live engine cap + memory-pressure hibernate). They are real resource controls — not a decorative GX gauge, and not a kernel CPU quota.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker("CPU governor", selection: Binding(
                    get: { governor.cpuLevel },
                    set: {
                        governor.cpuLevel = $0
                        governor.applyCPUThrottleToActiveTabs()
                    }
                )) {
                    ForEach(MacPerformanceGovernor.CPULevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                Picker("RAM governor", selection: Binding(
                    get: { governor.ramLevel },
                    set: { governor.ramLevel = $0 }
                )) {
                    ForEach(MacPerformanceGovernor.RAMLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                LabeledContent("Memory pressure", value: governor.memoryPressureLabel)
                if let reason = governor.lastHibernateReason {
                    Text("Last hibernate: \(reason)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Hibernate background tabs now") {
                    governor.hibernateUnderPressure(force: true)
                }
            } header: {
                Text("Governors")
            } footer: {
                Text("CPU stretches page timers/rAF. RAM lowers the live WKWebView cap and hibernates under pressure.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                LabeledContent("Native status") {
                    Text(
                        ChromiumNativeHost.isEmbeddedHostingReady
                            ? "Embedded CEF (in-tab Blink)"
                            : (ChromiumNativeHost.isEmbeddedFrameworkAvailable
                                ? "CEF on disk — rebuild with ORIEL_HAS_CEF"
                                : "Managed Chromium")
                    )
                }
                Text(ChromiumNativeHost.statusSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let url = environment.activeTab?.navigation.url,
                   !URLParser.isStartPage(url) {
                    Button("Open this page in Native Chromium…") {
                        _ = ChromiumNativeHost.openManagedNativeWindow(url)
                    }
                    .disabled(!ChromiumEngineBridge.systemChromiumInstalled
                              && !ChromiumNativeHost.isEmbeddedFrameworkAvailable)
                }
            } header: {
                Text("Chromium Native")
            } footer: {
                Text("In-tab Blink: fetch-cef-macos.sh + enable-cef-macos.sh + rebuild. Until ORIEL_HAS_CEF, Native uses a real Chromium app-window. See docs/CEF_NATIVE.md.")
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .navigationTitle("Mac Governors")
        #if os(macOS)
        .formStyle(.grouped)
        .frame(minWidth: 440, minHeight: 460)
        #endif
    }
}
