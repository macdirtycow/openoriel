import SwiftUI

struct FireButtonView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    @State private var options = FireClearOptions.default
    @State private var isBurning = false
    @State private var finishedMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Fire clears selected browsing data from this device. Bookmarks are never deleted.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Clear") {
                    Toggle("Browsing history", isOn: $options.history)
                    Toggle("Cookies & website data", isOn: $options.cookiesAndSiteData)
                    Toggle("Downloads list", isOn: $options.downloads)
                    Toggle("Reading List", isOn: $options.openLaterQueue)
                    Toggle("Site permissions", isOn: $options.sitePermissions)
                }

                Section("Tabs") {
                    Toggle("Close all tabs", isOn: $options.closeTabs)
                    Toggle("Close private tabs only", isOn: $options.closePrivateTabsOnly)
                        .disabled(options.closeTabs)
                }

                if let finishedMessage {
                    Section {
                        Text(finishedMessage)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Fire")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isBurning)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isBurning ? "Clearing…" : "Burn") {
                        Task { await burn() }
                    }
                    .disabled(isBurning || !hasSelection)
                    .tint(.red)
                }
            }
        }
    }

    private var hasSelection: Bool {
        options.history
            || options.cookiesAndSiteData
            || options.downloads
            || options.openLaterQueue
            || options.sitePermissions
            || options.closeTabs
            || options.closePrivateTabsOnly
    }

    private func burn() async {
        isBurning = true
        finishedMessage = nil
        await FireButtonService.burn(options: options, environment: environment)
        finishedMessage = "Cleared selected data."
        isBurning = false
        try? await Task.sleep(nanoseconds: 500_000_000)
        dismiss()
    }
}
