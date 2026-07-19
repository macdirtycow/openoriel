import SwiftUI

/// GX-style Pulse Corner — compact control strip for gaming chrome.
struct PulseCornerView: View {
    @Environment(AppEnvironment.self) private var environment

    private let quickLinks: [(String, String, String)] = [
        ("Twitch", "play.tv.fill", "https://www.twitch.tv"),
        ("YouTube", "play.rectangle.fill", "https://www.youtube.com"),
        ("Discord", "bubble.left.and.bubble.right.fill", "https://discord.com/app"),
        ("Steam", "gamecontroller.fill", "https://store.steampowered.com")
    ]

    private let newsLinks: [(String, String)] = [
        ("PC Gamer", "https://www.pcgamer.com"),
        ("The Verge Gaming", "https://www.theverge.com/games"),
        ("IGN", "https://www.ign.com")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Pulse Corner", systemImage: "bolt.horizontal.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(EditionBranding.pulseAccent)
                    Spacer()
                    Button {
                        environment.showPulseCorner = false
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Close Pulse Corner")
                }

                meterRow

                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick launch")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(quickLinks, id: \.0) { item in
                            Button {
                                if let url = URL(string: item.2) {
                                    environment.openURLInNewTab(url)
                                }
                            } label: {
                                Label(item.0, systemImage: item.1)
                                    .font(.caption.weight(.medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Gaming news")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(newsLinks, id: \.0) { item in
                        Button {
                            if let url = URL(string: item.1) {
                                environment.openURLInNewTab(url)
                            }
                        } label: {
                            Text(item.0)
                                .font(.caption)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(EditionBranding.pulseAccent)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Data Saver", isOn: Binding(
                        get: { environment.settings.pulseDataSaver },
                        set: {
                            environment.settings.pulseDataSaver = $0
                            environment.syncPulseRuntimeFlags()
                        }
                    ))
                    Toggle("Network Saver", isOn: Binding(
                        get: { environment.settings.pulseNetworkSaver },
                        set: {
                            environment.settings.pulseNetworkSaver = $0
                            environment.syncPulseRuntimeFlags()
                        }
                    ))
                    Toggle("Lucid Mode", isOn: Binding(
                        get: { environment.settings.pulseLucidMode },
                        set: {
                            environment.settings.pulseLucidMode = $0
                            environment.syncPulseRuntimeFlags()
                        }
                    ))
                    Toggle("Battery Saver", isOn: Binding(
                        get: { environment.settings.pulseBatterySaver },
                        set: {
                            environment.settings.pulseBatterySaver = $0
                            environment.syncPulseRuntimeFlags()
                        }
                    ))
                    Toggle("Corner stays open", isOn: Binding(
                        get: { environment.settings.pulseCornerEnabled },
                        set: { environment.settings.pulseCornerEnabled = $0 }
                    ))
                }
                .font(.caption)
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Ambience")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Picker("Ambience", selection: Binding(
                        get: { environment.pulseAmbience.track },
                        set: { environment.pulseAmbience.select($0) }
                    )) {
                        ForEach(PulseAmbiencePlayer.Track.allCases) { track in
                            Text(track.displayName).tag(track)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                HStack(spacing: 8) {
                    Button("Performance") {
                        environment.showPulsePerformance = true
                    }
                    .buttonStyle(.bordered)
                    Button("Shields") {
                        environment.showPrivacyShield = true
                    }
                    .buttonStyle(.bordered)
                }
                .font(.caption)

                Button("Hibernate background tabs") {
                    environment.hibernateBackgroundTabs()
                }
                .font(.caption)
                .buttonStyle(.bordered)

                #if os(macOS)
                if let url = environment.activeTab?.navigation.url,
                   !URLParser.isStartPage(url) {
                    Button("Open in system Chrome…") {
                        _ = ChromiumEngineBridge.openInSystemChromium(url)
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .disabled(!ChromiumEngineBridge.systemChromiumInstalled)
                }
                #endif
            }
            .padding(14)
        }
        .frame(width: 280)
        .frame(maxHeight: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(EditionBranding.pulseAccent.opacity(0.35), lineWidth: 1)
        }
    }

    private var meterRow: some View {
        let tabs = environment.tabs.tabs.count
        let limit = WebViewPool.shared.softLimit
        let engine = RenderingEnginePolicy.resolved(environment.settings.preferredEngine)
        return VStack(alignment: .leading, spacing: 4) {
            Text("Tabs \(tabs) · Engine cap \(limit)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(engine.displayName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if environment.settings.effectiveDataSaver || environment.settings.pulseNetworkSaver {
                Text([
                    environment.settings.effectiveDataSaver ? "images off" : nil,
                    environment.settings.pulseNetworkSaver ? "media/fonts off" : nil
                ].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(.tertiary)
            }
        }
    }
}
