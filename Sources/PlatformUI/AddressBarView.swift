import SwiftUI

struct AddressBarView: View {
    @Bindable var tab: BrowserTab
    var searchEngine: SearchEngine = .duckDuckGo
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: securitySymbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(securityColor)
                .accessibilityLabel(securityAccessibilityLabel)

            TextField(searchEngine.addressBarPlaceholder, text: $tab.navigation.addressBarText)
                .textFieldStyle(.plain)
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                #endif
                .submitLabel(.go)
                .onSubmit(onSubmit)
                .accessibilityLabel("Address and search")
                .accessibilityValue(tab.navigation.addressBarText)
                .accessibilityHint("Searches with \(searchEngine.displayName) when the text is not a web address")

            if tab.navigation.isLoading {
                Button {
                    tab.stopLoading()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop loading")
            } else if !tab.navigation.addressBarText.isEmpty {
                Button {
                    tab.navigation.addressBarText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear address")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var securitySymbol: String {
        if URLParser.isStartPage(tab.navigation.url) {
            return "shield.lefthalf.filled"
        }
        if tab.navigation.url?.scheme?.lowercased() == "https" {
            return "lock.fill"
        }
        if tab.navigation.lastErrorMessage != nil {
            return "exclamationmark.shield.fill"
        }
        return "lock.open.fill"
    }

    private var securityColor: Color {
        if tab.navigation.url?.scheme?.lowercased() == "https" {
            return .secondary
        }
        if tab.navigation.lastErrorMessage != nil {
            return .orange
        }
        return .secondary
    }

    private var securityAccessibilityLabel: String {
        if URLParser.isStartPage(tab.navigation.url) {
            return "Oriel start page"
        }
        if tab.navigation.url?.scheme?.lowercased() == "https" {
            return "Secure connection"
        }
        return "Connection security unknown"
    }
}
