import SwiftUI

/// Settings page: what Oriel keeps on device, in iCloud, and in Keychain.
struct DataInventoryView: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        Form {
            Section {
                Text("Oriel is designed to keep browsing data on your devices. This page lists what is stored where.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("On this device") {
                inventoryRow("Bookmarks", detail: "\(environment.bookmarks.bookmarks.filter { !$0.isFolder }.count) items", systemImage: "bookmark.fill")
                inventoryRow("History", detail: "Recent visits on this device", systemImage: "clock")
                inventoryRow("Open tabs", detail: "\(environment.tabs.tabs.count) tabs", systemImage: "square.on.square")
                inventoryRow("Reading List", detail: "\(environment.linkQueue.count) saved pages", systemImage: "text.book.closed.fill")
                inventoryRow("Downloads", detail: "Files in your Downloads folder", systemImage: "arrow.down.circle")
                inventoryRow("Shields stats", detail: "Blocked trackers this session and lifetime", systemImage: "shield.lefthalf.filled")
                inventoryRow("Extensions", detail: "\(environment.extensions.extensions.count) installed packages", systemImage: "puzzlepiece.extension.fill")
                inventoryRow("Profiles", detail: "\(environment.profiles.profiles.count) cookie jars", systemImage: "person.crop.circle")
                inventoryRow("Site permissions", detail: "Camera, mic, and location choices", systemImage: "hand.raised.fill")
            }

            Section("iCloud Key Value (optional)") {
                if environment.icloudSync.isEnabled {
                    Label("Sync is on", systemImage: "checkmark.icloud.fill")
                        .foregroundStyle(environment.settings.brandColor)
                } else {
                    Label("Sync is off", systemImage: "icloud.slash")
                        .foregroundStyle(.secondary)
                }
                Text("When enabled: bookmarks, Reading List, open tabs, limited history (up to 200), and appearance settings. Not passwords.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("System Keychain") {
                Text("Passwords and passkeys stay in the system Keychain. Oriel can fill them via the system picker. Oriel does not keep its own password database.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Private browsing") {
                Text("Private tabs use a temporary data store. They are not restored after quit and are not synced.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Clear") {
                Button("Open Fire…", role: .destructive) {
                    environment.showFireButton = true
                }
            } footer: {
                Text("Fire clears selected browsing data on this device. Bookmarks are never deleted by Fire.")
            }
        }
        .navigationTitle("What Oriel stores")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
    }

    private func inventoryRow(_ title: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .frame(width: 28)
                .foregroundStyle(environment.settings.brandColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
