import SwiftUI

#if os(iOS)
import UIKit
#endif

struct DefaultBrowserSettingsPage: View {
    @Environment(AppEnvironment.self) private var environment

    var body: some View {
        let browser = environment.defaultBrowser
        Form {
            Section {
                Text(browser.platformGuidance)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let status = browser.lastStatusMessage {
                    Label(status, systemImage: browser.isDefaultBrowser ? "checkmark.seal.fill" : "safari")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if let error = browser.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if browser.canSetAsDefaultDirectly {
                    Button("Set Oriel as Default Browser") {
                        browser.promoteToDefaultBrowser()
                    }
                    Button("Open System Settings") {
                        browser.openDefaultBrowserSettings()
                    }
                } else {
                    Button("Open Default Browser Settings") {
                        browser.promoteToDefaultBrowser()
                    }
                }
            } footer: {
                #if os(macOS)
                Text("Oriel registers for http and https links.")
                #else
                Text("Apple must approve the Default Browser entitlement before Oriel appears in Settings. Sideloaded builds can still open shared links.")
                #endif
            }

            #if os(iOS)
            Section {
                checklistRow(done: true, title: "Register http and https", detail: "Already in the app Info.plist")
                checklistRow(done: false, title: "Apple Default Browser entitlement", detail: "Request access from Apple Developer")
                checklistRow(done: false, title: "Ship an entitled build", detail: "Then choose Oriel under Default Browser App")
                Link(
                    "Request Default Browser access",
                    destination: URL(string: "https://developer.apple.com/contact/request/default-browser/")!
                )
            } header: {
                Text("Checklist")
            }
            #endif
        }
        .navigationTitle("Default browser")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .onAppear { browser.refreshStatus() }
    }

    #if os(iOS)
    private func checklistRow(done: Bool, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: done ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(done ? environment.settings.brandColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    #endif
}
