import SwiftUI

struct AboutOrielView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme

    private var pageScheme: ColorScheme {
        environment.settings.backgroundTheme.resolvedColorScheme(system: systemColorScheme)
    }

    private var accent: Color {
        environment.settings.accentTheme.readable(on: pageScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    OrielMark(size: 78)
                        .shadow(
                            color: (environment.settings.edition.isPulse
                                    ? EditionBranding.pulseAccent
                                    : accent).opacity(environment.settings.edition.isPulse ? 0.12 : 0.22),
                            radius: environment.settings.edition.isPulse ? 10 : 18,
                            y: 6
                        )
                        .padding(.top, 12)

                    VStack(spacing: 8) {
                        if environment.settings.edition.isPulse {
                            Text("ORIEL")
                                .font(EditionBranding.pulseEyebrowFont(size: 11))
                                .tracking(EditionBranding.pulseEyebrowTracking)
                                .foregroundStyle(EditionBranding.pulseSteel.opacity(0.9))
                            Text("Pulse")
                                .font(EditionBranding.productTitleFont(for: environment.settings.edition, size: 36))
                                .tracking(EditionBranding.productTitleTracking(for: environment.settings.edition))
                                .foregroundStyle(.primary)
                        } else {
                            Text(EditionBranding.productName(for: environment.settings.edition))
                                .font(EditionBranding.productTitleFont(for: environment.settings.edition, size: 32))
                                .tracking(EditionBranding.productTitleTracking(for: environment.settings.edition))
                                .foregroundStyle(.primary)
                        }

                        Text(EditionBranding.tagline(for: environment.settings.edition))
                            .font(.title3)
                            .foregroundStyle(.secondary)

                        Text("A native browser for Apple platforms.")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }

                    VStack(spacing: 14) {
                        aboutLink(
                            title: "Website",
                            value: BrowserConstants.productWebsiteHost,
                            url: BrowserConstants.productWebsiteURL
                        )
                        aboutLink(
                            title: "Publisher",
                            value: BrowserConstants.publisherName,
                            url: BrowserConstants.publisherURL
                        )
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity)
                    .background(
                        OrielTheme.surfaceFill(for: pageScheme),
                        in: RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: OrielTheme.sectionRadius, style: .continuous)
                            .strokeBorder(OrielTheme.hairline(for: pageScheme), lineWidth: 1)
                    }
                    .padding(.top, 8)

                    Text("Uses Apple’s WebKit framework. Privacy protections are limited by what WebKit and the OS expose.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)

                    Text("© 2025–2026 \(BrowserConstants.publisherName)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 4)
                }
                .padding(24)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .background {
                OrielTheme.startPageBackground(
                    accent: environment.settings.accentTheme,
                    background: environment.settings.backgroundTheme,
                    scheme: pageScheme
                )
            }
            .environment(\.colorScheme, pageScheme)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
    }

    private func aboutLink(title: String, value: String, url: URL) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Link(value, destination: url)
                .font(.headline.weight(.semibold))
                .foregroundStyle(accent)
        }
        .frame(maxWidth: .infinity)
    }
}
