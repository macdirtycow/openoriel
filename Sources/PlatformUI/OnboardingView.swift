import SwiftUI

/// First-launch tour covering privacy, profiles, extensions, and default browser.
struct OnboardingView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            symbol: "sparkles",
            title: "Welcome to Oriel",
            body: "A calm, privacy-minded browser for iPhone, iPad, and Mac. This short tour covers the essentials."
        ),
        OnboardingPage(
            symbol: "shield.lefthalf.filled",
            title: "Privacy Shields",
            body: "Shields block trackers and cookie banners. Open the shield button anytime to tune protection per site or globally."
        ),
        OnboardingPage(
            symbol: "person.crop.circle",
            title: "Profiles",
            body: "Each profile keeps its own cookies and site data. Switch from the profile control in the toolbar or start page when you need separate logins."
        ),
        OnboardingPage(
            symbol: "puzzlepiece.extension",
            title: "Extensions",
            body: "Install Chrome Web Store or WebExtension packages (.zip / .crx). Safari App Store extensions stay tied to Safari — Oriel uses the open WebExtensions format instead."
        ),
        OnboardingPage(
            symbol: "safari",
            title: "Default browser",
            body: "Make Oriel open links from other apps. On Mac you can set it here. On iPhone and iPad, choose Oriel in Settings once Apple’s default-browser entitlement is active."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button("Skip") { finish() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    pageContent(item)
                        .tag(index)
                        .padding(.horizontal, 28)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .always))
            #else
            .frame(maxHeight: .infinity)
            #endif

            VStack(spacing: 12) {
                #if os(macOS)
                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? environment.settings.brandColor : Color.primary.opacity(0.15))
                            .frame(width: index == page ? 22 : 8, height: 8)
                    }
                }
                .padding(.bottom, 4)
                #endif

                if page == pages.count - 1 {
                    defaultBrowserActions
                }

                Button {
                    if page < pages.count - 1 {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            page += 1
                        }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Continue" : "Start browsing")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(environment.settings.brandColor)

                if page > 0 {
                    Button("Back") {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                            page -= 1
                        }
                    }
                    .font(.subheadline.weight(.medium))
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
            .padding(.top, 8)
        }
        .background {
            OrielTheme.startPageBackground(
                accent: environment.settings.accentTheme,
                background: environment.settings.backgroundTheme,
                scheme: .light
            )
            .ignoresSafeArea()
        }
    }

    private func pageContent(_ item: OnboardingPage) -> some View {
        VStack(spacing: 22) {
            Spacer(minLength: 12)
            OrielMark(size: 64)
            Image(systemName: item.symbol)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(environment.settings.brandColor)
                .padding(.top, 4)
            Text(item.title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .multilineTextAlignment(.center)
            Text(item.body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 12)
        }
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var defaultBrowserActions: some View {
        let service = environment.defaultBrowser
        VStack(alignment: .leading, spacing: 10) {
            Text(service.platformGuidance)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if service.canSetAsDefaultDirectly {
                Button("Set Oriel as Default Browser") {
                    service.promoteToDefaultBrowser()
                }
                .buttonStyle(.bordered)
            } else {
                Button("Open Default Browser Settings") {
                    service.promoteToDefaultBrowser()
                }
                .buttonStyle(.bordered)
            }

            if let status = service.lastStatusMessage {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let error = service.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { service.refreshStatus() }
    }

    private func finish() {
        environment.settings.hasCompletedOnboarding = true
    }
}

private struct OnboardingPage: Hashable {
    var symbol: String
    var title: String
    var body: String
}
