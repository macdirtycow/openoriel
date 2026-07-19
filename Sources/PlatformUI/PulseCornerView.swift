import SwiftUI

/// Compact Pulse control strip — studio chrome, not stock bordered controls.
struct PulseCornerView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showNews = false
    @State private var appeared = false

    private let quickLinks: [(String, String)] = [
        ("Twitch", "https://www.twitch.tv"),
        ("YouTube", "https://www.youtube.com"),
        ("Discord", "https://discord.com/app"),
        ("Steam", "https://store.steampowered.com")
    ]

    private let newsLinks: [(String, String)] = [
        ("PC Gamer", "https://www.pcgamer.com"),
        ("The Verge Gaming", "https://www.theverge.com/games"),
        ("IGN", "https://www.ign.com")
    ]

    private var accent: Color { EditionBranding.pulseAccent }
    private var steel: Color { EditionBranding.pulseSteel }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusBlock
                launchBlock
                newsBlock
                saverBlock
                ambienceBlock
                actionRow
            }
            .padding(16)
        }
        .frame(width: 272)
        .frame(maxHeight: 520)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(EditionBranding.pulseNavy.opacity(0.92))
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial.opacity(0.55))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [steel.opacity(0.35), accent.opacity(0.28), steel.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .opacity(appeared || reduceMotion ? 1 : 0)
        .offset(y: appeared || reduceMotion ? 0 : 8)
        .onAppear {
            if reduceMotion {
                appeared = true
            } else {
                withAnimation(.spring(response: 0.45, dampingFraction: 0.88)) {
                    appeared = true
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            OrielMark(size: 28, forcePulse: true)
            VStack(alignment: .leading, spacing: 2) {
                Text("ORIEL")
                    .font(EditionBranding.pulseEyebrowFont(size: 9))
                    .tracking(EditionBranding.pulseEyebrowTracking)
                    .foregroundStyle(steel.opacity(0.85))
                Text("Pulse Corner")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
            Button {
                environment.showPulseCorner = false
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Pulse Corner")
        }
    }

    private var statusBlock: some View {
        let tabs = environment.tabs.tabs.count
        let limit = WebViewPool.shared.softLimit
        let engine = environment.resolvedEngine(for: environment.activeTab)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Capsule(style: .continuous)
                    .fill(accent)
                    .frame(width: 6, height: 6)
                Text("\(tabs) tabs · cap \(limit)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Text(engine.displayName)
                .font(.caption2)
                .foregroundStyle(.tertiary)
            if environment.settings.effectiveDataSaver || environment.settings.pulseNetworkSaver {
                Text([
                    environment.settings.effectiveDataSaver ? "Images off" : nil,
                    environment.settings.pulseNetworkSaver ? "Media off" : nil
                ].compactMap { $0 }.joined(separator: " · "))
                .font(.caption2)
                .foregroundStyle(accent.opacity(0.9))
            }
        }
        .padding(.vertical, 4)
    }

    private var launchBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Launch")
            HStack(spacing: 0) {
                ForEach(Array(quickLinks.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Rectangle()
                            .fill(steel.opacity(0.18))
                            .frame(width: 1, height: 14)
                    }
                    Button {
                        if let url = URL(string: item.1) {
                            environment.openURLInNewTab(url)
                        }
                    } label: {
                        Text(item.0)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(steel.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var newsBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showNews.toggle() }
            } label: {
                HStack {
                    sectionLabel("News")
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showNews ? 180 : 0))
                }
            }
            .buttonStyle(.plain)
            if showNews {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(newsLinks, id: \.0) { item in
                        Button {
                            if let url = URL(string: item.1) {
                                environment.openURLInNewTab(url)
                            }
                        } label: {
                            Text(item.0)
                                .font(.caption)
                                .foregroundStyle(accent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var saverBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Performance")
            saverToggle("Data Saver", isOn: Binding(
                get: { environment.settings.pulseDataSaver },
                set: {
                    environment.settings.pulseDataSaver = $0
                    environment.syncPulseRuntimeFlags()
                }
            ))
            saverToggle("Network Saver", isOn: Binding(
                get: { environment.settings.pulseNetworkSaver },
                set: {
                    environment.settings.pulseNetworkSaver = $0
                    environment.syncPulseRuntimeFlags()
                }
            ))
            saverToggle("Lucid Mode", isOn: Binding(
                get: { environment.settings.pulseLucidMode },
                set: {
                    environment.settings.pulseLucidMode = $0
                    environment.syncPulseRuntimeFlags()
                }
            ))
            saverToggle("Battery Saver", isOn: Binding(
                get: { environment.settings.pulseBatterySaver },
                set: {
                    environment.settings.pulseBatterySaver = $0
                    environment.syncPulseRuntimeFlags()
                }
            ))
            saverToggle("Keep Corner open", isOn: Binding(
                get: { environment.settings.pulseCornerEnabled },
                set: { environment.settings.pulseCornerEnabled = $0 }
            ))
        }
    }

    private var ambienceBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("Ambience")
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
            if environment.pulseAmbience.track != .off {
                Slider(value: Binding(
                    get: { Double(environment.pulseAmbience.volume) },
                    set: { environment.pulseAmbience.volume = Float($0) }
                ), in: 0...0.6)
                .tint(accent)
            }
        }
    }

    private var actionRow: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                textAction("Shields") { environment.showPrivacyShield = true }
                textAction("Controls") { environment.showPulsePerformance = true }
            }
            Button {
                environment.hibernateBackgroundTabs()
            } label: {
                Text("Hibernate background tabs")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(steel.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            #if os(macOS)
            if let url = environment.activeTab?.navigation.url,
               !URLParser.isStartPage(url) {
                Button {
                    _ = ChromiumEngineBridge.openInSystemChromium(url)
                } label: {
                    Text("Open in system Chrome…")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(!ChromiumEngineBridge.systemChromiumInstalled)
            }
            #endif
        }
        .padding(.top, 2)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .semibold, design: .default))
            .tracking(1.4)
            .foregroundStyle(steel.opacity(0.75))
    }

    private func saverToggle(_ title: String, isOn: Binding<Bool>) -> some View {
        Toggle(title, isOn: isOn)
            .font(.caption.weight(.medium))
            .tint(accent)
            .toggleStyle(.switch)
    }

    private func textAction(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(steel.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(steel.opacity(0.16), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}
