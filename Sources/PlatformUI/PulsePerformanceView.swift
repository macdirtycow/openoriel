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
                Text("Oriel Pulse can limit live page engines, block images (Data Saver), react to Low Power Mode, and play local ambience. This is not a system CPU, RAM, or network governor — WebKit does not expose that.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker("Live page engines", selection: Binding(
                    get: { environment.settings.pulseWebViewLimit },
                    set: {
                        environment.settings.pulseWebViewLimit = $0
                        environment.syncPulseRuntimeFlags()
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
                        environment.syncPulseRuntimeFlags()
                        environment.icloudSync.noteLocalChange()
                    }
                ))
                Toggle("Data Saver (block images)", isOn: Binding(
                    get: { environment.settings.pulseDataSaver },
                    set: {
                        environment.settings.pulseDataSaver = $0
                        environment.syncPulseRuntimeFlags()
                        environment.icloudSync.noteLocalChange()
                    }
                ))
                Toggle("Battery Saver (follow Low Power Mode)", isOn: Binding(
                    get: { environment.settings.pulseBatterySaver },
                    set: {
                        environment.settings.pulseBatterySaver = $0
                        environment.syncPulseRuntimeFlags()
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
                Text("Data Saver uses a WebKit content rule for images. Battery Saver tightens the engine cap when iOS/macOS Low Power Mode is on.")
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                Picker("Ambience", selection: Binding(
                    get: { environment.pulseAmbience.track },
                    set: { environment.pulseAmbience.select($0) }
                )) {
                    ForEach(PulseAmbiencePlayer.Track.allCases) { track in
                        Text(track.displayName).tag(track)
                    }
                }
                if environment.pulseAmbience.track != .off {
                    Slider(value: Binding(
                        get: { Double(environment.pulseAmbience.volume) },
                        set: { environment.pulseAmbience.volume = Float($0) }
                    ), in: 0...0.6)
                }
            } header: {
                Text("Soundscape")
            } footer: {
                Text("Local procedural tones only — nothing is uploaded or streamed from a third party.")
            }

            Section {
                Toggle("Show Pulse Corner", isOn: Binding(
                    get: { environment.showPulseCorner },
                    set: {
                        environment.showPulseCorner = $0
                        environment.settings.pulseCornerEnabled = $0
                    }
                ))
                #if os(iOS)
                if environment.appIcon.supportsAlternateIcons {
                    Toggle("Pulse home-screen icon", isOn: Binding(
                        get: { environment.appIcon.isPulseIconActive },
                        set: { enabled in
                            Task { await environment.appIcon.setPulseIcon(enabled) }
                        }
                    ))
                }
                #else
                Toggle("Pulse Dock icon", isOn: Binding(
                    get: { environment.appIcon.isPulseIconActive },
                    set: { enabled in
                        Task { await environment.appIcon.setPulseIcon(enabled) }
                    }
                ))
                #endif
                if let error = environment.appIcon.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            } header: {
                Text("Chrome")
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
            }

            Section {
                Button("Switch back to Classic Oriel") {
                    environment.selectBrowserEdition(.classic, applySuggestedLook: true)
                    environment.extensionThemes.clearActive()
                    Task { await environment.appIcon.setPulseIcon(false) }
                    if showsDoneButton { dismiss() }
                }
            }
        }
    }
}
