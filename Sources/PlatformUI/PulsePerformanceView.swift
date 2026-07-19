import SwiftUI

/// Pulse performance controls — honest WebKit-safe limits (not Chromium CPU/RAM gauges).
struct PulsePerformanceView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    /// When true (sheet), wrap in NavigationStack with Done. When false, embed in an existing stack.
    var showsDoneButton: Bool = true

    var body: some View {
        if showsDoneButton {
            NavigationStack {
                formContent
                    .navigationTitle("Pulse")
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { dismiss() }
                        }
                    }
            }
        } else {
            formContent
                .navigationTitle("Pulse")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
    }

    private var formContent: some View {
        Form {
            Section {
                Text("Oriel Pulse can limit how many live page engines stay in memory. This is not a system CPU or RAM governor like some desktop gaming browsers claim — WebKit does not expose that.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker("Live page engines", selection: Binding(
                    get: { environment.settings.pulseWebViewLimit },
                    set: {
                        environment.settings.pulseWebViewLimit = $0
                        environment.icloudSync.noteLocalChange()
                    }
                )) {
                    Text("4 (strict)").tag(4)
                    Text("6").tag(6)
                    Text("8 (default)").tag(8)
                    Text("12").tag(12)
                }
                Toggle("Unload idle background tabs sooner", isOn: Binding(
                    get: { environment.settings.pulseAggressiveTabUnload },
                    set: {
                        environment.settings.pulseAggressiveTabUnload = $0
                        environment.icloudSync.noteLocalChange()
                    }
                ))
                Toggle("Block media autoplay", isOn: Binding(
                    get: { environment.settings.blockAutoplay },
                    set: {
                        environment.settings.blockAutoplay = $0
                        environment.icloudSync.noteLocalChange()
                    }
                ))
            } header: {
                Text("Performance")
            } footer: {
                Text("Lower engine counts free memory when you keep many tabs open. Active and protected tabs are kept.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Toggle("Shields on", isOn: Binding(
                    get: { environment.privacy.contentBlockingEnabled },
                    set: {
                        environment.privacy.contentBlockingEnabled = $0
                        environment.privacy.httpsUpgradeEnabled = $0
                    }
                ))
                Toggle("HTTPS-Only Mode", isOn: Binding(
                    get: { environment.privacy.httpsOnlyMode },
                    set: { environment.privacy.httpsOnlyMode = $0 }
                ))
                Button("Open Shields…") {
                    if showsDoneButton { dismiss() }
                    environment.showPrivacyShield = true
                }
            } header: {
                Text("Privacy HUD")
            } footer: {
                Text("Same Oriel privacy stack — Pulse only changes chrome and performance knobs.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Button("Switch back to Classic Oriel") {
                    environment.settings.selectEdition(.classic, applySuggestedLook: true)
                    environment.extensionThemes.clearActive()
                    environment.icloudSync.noteLocalChange()
                    if showsDoneButton { dismiss() }
                }
            }
        }
    }
}
