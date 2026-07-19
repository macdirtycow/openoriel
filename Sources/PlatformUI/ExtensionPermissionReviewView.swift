import SwiftUI

/// Install-time permission review before granting WKWebExtension permissions.
struct ExtensionPermissionReviewView: View {
    @Environment(\.dismiss) private var dismiss

    let extensionName: String
    let permissions: [String]
    let hostPatterns: [String]
    let onConfirm: ([String]) -> Void
    let onCancel: () -> Void

    @State private var selected: Set<String> = []

    private var accentPermissions: [String] {
        permissions.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("“\(extensionName)” wants access to:")
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !accentPermissions.isEmpty {
                    Section("Permissions") {
                        ForEach(accentPermissions, id: \.self) { permission in
                            Toggle(isOn: Binding(
                                get: { selected.contains(permission) },
                                set: { on in
                                    if on { selected.insert(permission) } else { selected.remove(permission) }
                                }
                            )) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(permission)
                                        .font(.body.weight(.medium))
                                    Text(Self.blurb(for: permission))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .disabled(ExtensionCompatibility.blockedPermissions.contains(permission))
                        }
                    } footer: {
                        Text("Blocked WebKit APIs stay off. Limited APIs may still not work fully.")
                    }
                } else {
                    Section {
                        Text("No explicit permissions were declared. Oriel will still apply WebKit-safe defaults.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if !hostPatterns.isEmpty {
                    Section("Sites") {
                        ForEach(hostPatterns.prefix(12), id: \.self) { pattern in
                            Text(pattern)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        if hostPatterns.count > 12 {
                            Text("\(hostPatterns.count - 12) more patterns")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .navigationTitle("Review permissions")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Allow") {
                        onConfirm(Array(selected))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                selected = Set(accentPermissions.filter { !ExtensionCompatibility.blockedPermissions.contains($0) })
            }
        }
    }

    static func blurb(for permission: String) -> String {
        switch permission {
        case "tabs": return "See open tabs and their URLs"
        case "storage": return "Save extension settings on this device"
        case "cookies": return "Read or change site cookies"
        case "webRequest", "webRequestBlocking": return "Inspect or block network requests"
        case "downloads": return "Start or manage downloads"
        case "history": return "Read browsing history"
        case "notifications": return "Show notifications"
        case "clipboardRead", "clipboardWrite": return "Use the clipboard"
        case "identity": return "Sign-in flows"
        case "<all_urls>", "*://*/*": return "Access every website"
        default:
            if ExtensionCompatibility.blockedPermissions.contains(permission) {
                return "Not available in Oriel (WebKit)"
            }
            if ExtensionCompatibility.limitedPermissions.contains(permission) {
                return "Limited support on WebKit"
            }
            return "Extension capability"
        }
    }
}
