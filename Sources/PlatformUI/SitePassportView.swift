import SwiftUI

/// One place for per-site decisions — unique Oriel packaging of engine, zoom, mute, Shields.
struct SitePassportView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private var tab: BrowserTab? { environment.activeTab }

    private var host: String {
        tab?.navigation.url?.host ?? "This page"
    }

    private var concreteEngine: BrowserEngineKind {
        environment.resolvedEngine(for: tab)
    }

    private var engineReason: String {
        environment.engineReason(for: tab)
    }

    private var zoomPercent: Int {
        guard let host = tab?.navigation.url?.host else { return 100 }
        let level = environment.siteZoom.zoom(forHost: host)
        return Int((level * 100).rounded())
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        FaviconImage(pageURL: tab?.navigation.url, size: 36)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(host)
                                .font(.headline)
                            Text(tab?.displayTitle ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Engine") {
                    LabeledContent("Active", value: concreteEngine.displayName)
                    Text(engineReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    #if os(macOS)
                    if environment.settings.preferredEngine == .smart || tab?.engineOverride != nil {
                        Button("Open engine settings…") {
                            dismiss()
                            environment.showChromiumFeatures = true
                        }
                    }
                    #endif
                }

                Section("Page") {
                    LabeledContent("Zoom", value: "\(zoomPercent)%")
                    LabeledContent(
                        "Sound",
                        value: tab?.isMediaMuted == true ? "Muted" : "On"
                    )
                    Toggle("Mute this tab", isOn: Binding(
                        get: { tab?.isMediaMuted ?? false },
                        set: { tab?.setMediaMuted($0) }
                    ))
                    .disabled(tab?.isShowingStartPage != false)
                }

                Section("Shields") {
                    Toggle("Content blocking", isOn: Binding(
                        get: { environment.privacy.contentBlockingEnabled },
                        set: {
                            environment.privacy.contentBlockingEnabled = $0
                            environment.privacy.httpsUpgradeEnabled = $0
                        }
                    ))
                    Button("Shield details…") {
                        dismiss()
                        environment.showPrivacyShield = true
                    }
                }

                Section {
                    Button("Reset zoom for this site", role: .destructive) {
                        if let host = tab?.navigation.url?.host {
                            environment.siteZoom.setZoom(1, forHost: host)
                            tab?.applyPageEnhancementsAfterLoad()
                        }
                    }
                    .disabled(tab?.navigation.url?.host == nil)
                }
            }
            .navigationTitle("Site Passport")
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
}
