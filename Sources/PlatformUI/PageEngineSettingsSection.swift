import SwiftUI

/// Page-engine picker shared by Classic and Pulse (Settings → Appearance, Pulse panel).
struct PageEngineSettingsSection: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        #if os(macOS)
        Section {
            ForEach(BrowserEngineKind.availableOnThisPlatform) { engine in
                Button {
                    environment.settings.preferredEngine = engine
                    environment.syncPulseRuntimeFlags()
                    environment.icloudSync.noteLocalChange()
                    if let tab = environment.activeTab, !tab.isShowingStartPage {
                        tab.reload()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: engine.systemImage)
                            .foregroundStyle(environment.settings.brandColor)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(engine.displayName)
                                .foregroundStyle(.primary)
                            Text(engine.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        if environment.settings.preferredEngine == engine {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(environment.settings.brandColor)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
            if environment.settings.preferredEngine == .chromiumNative,
               RenderingEnginePolicy.chromiumNativeStatus != .available {
                Text(RenderingEnginePolicy.chromiumNativeStatus.userMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if ChromiumEngineBridge.systemChromiumInstalled,
               let url = environment.activeTab?.navigation.url,
               !URLParser.isStartPage(url) {
                Button("Open current page in system Chrome…") {
                    _ = ChromiumEngineBridge.openInSystemChromium(url)
                }
            }
            NavigationLink {
                ChromiumFeaturesView(showsDoneButton: false)
            } label: {
                Label("Chromium features…", systemImage: "cpu")
            }
        } header: {
            Text("Page engine")
        } footer: {
            Text("Works in Classic and Pulse. Default is Smart: each tab picks WebKit or Chromium Compatible from the page. Chromium Compatible keeps WebKit painting with Chrome’s desktop identity and Client Hints. Chromium Native uses embedded CEF when installed, otherwise a managed system Chromium app-window on Mac.")
                .fixedSize(horizontal: false, vertical: true)
        }
        #else
        Section {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: BrowserEngineKind.webkit.systemImage)
                    .foregroundStyle(environment.settings.brandColor)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(BrowserEngineKind.webkit.displayName)
                    Text(ChromiumNativeStatus.unavailableOnIOS.userMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } header: {
            Text("Page engine")
        } footer: {
            Text("Same for Classic and Pulse. Mac builds can also choose Chromium Compatible or Native.")
                .fixedSize(horizontal: false, vertical: true)
        }
        #endif
    }
}
