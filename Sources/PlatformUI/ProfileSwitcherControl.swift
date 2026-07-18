import SwiftUI

/// Compact profile switcher for browser chrome and the start page.
struct ProfileSwitcherControl: View {
    @Environment(AppEnvironment.self) private var environment
    var style: Style = .chip

    enum Style {
        case chip
        case icon
        case menuLabel
    }

    private var activeName: String {
        environment.profiles.activeProfile.name
    }

    var body: some View {
        Menu {
            Section("Profiles") {
                ForEach(environment.profiles.profiles) { profile in
                    Button {
                        environment.applyProfile(id: profile.id)
                    } label: {
                        Label {
                            Text(profile.name)
                        } icon: {
                            if profile.id == environment.profiles.activeProfileID {
                                Image(systemName: "checkmark")
                            } else {
                                Image(systemName: profileAvatarSymbol(for: profile))
                            }
                        }
                    }
                }
            }

            Divider()

            Button("Manage Profiles…") {
                environment.showProfiles = true
            }
            Button("New Profile…") {
                environment.showProfiles = true
            }
        } label: {
            labelContent
        }
        .accessibilityLabel("Profile, \(activeName)")
        .help("Switch profile")
    }

    @ViewBuilder
    private var labelContent: some View {
        switch style {
        case .chip:
            HStack(spacing: 6) {
                Image(systemName: "person.crop.circle.fill")
                    .imageScale(.medium)
                Text(activeName)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2.weight(.bold))
                    .opacity(0.55)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                environment.settings.brandColor.opacity(0.14),
                in: Capsule(style: .continuous)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(environment.settings.brandColor.opacity(0.28), lineWidth: 1)
            }
        case .icon:
            Image(systemName: "person.crop.circle")
                .symbolRenderingMode(.hierarchical)
                .imageScale(.medium)
        case .menuLabel:
            Label(activeName, systemImage: "person.crop.circle")
        }
    }

    private func profileAvatarSymbol(for profile: BrowserProfile) -> String {
        if profile.isPrivateContainer { return "eyeglasses" }
        return "person.crop.circle"
    }
}
