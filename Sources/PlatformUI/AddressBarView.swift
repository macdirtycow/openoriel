import SwiftUI

struct AddressBarView: View {
    enum SuggestionsPlacement {
        case below
        case above
    }

    @Environment(AppEnvironment.self) private var environment
    @Bindable var tab: BrowserTab
    var searchEngine: SearchEngine = .duckDuckGo
    var suggestionsPlacement: SuggestionsPlacement = .below
    var onSubmit: () -> Void

    @State private var suggestions: [SearchSuggestion] = []
    @State private var suggestionTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    private var accent: Color {
        environment.settings.brandColor
    }

    private var showSuggestions: Bool {
        isFocused
            && !tab.navigation.addressBarText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !suggestions.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSuggestions && suggestionsPlacement == .above {
                suggestionList
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

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
                    .focused($isFocused)
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
                        suggestions = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear address")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                    .strokeBorder(
                        isFocused ? accent.opacity(0.35) : Color.primary.opacity(0.07),
                        lineWidth: isFocused ? 1.5 : 1
                    )
            }

            if showSuggestions && suggestionsPlacement == .below {
                suggestionList
                    .padding(.top, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .onChange(of: tab.navigation.addressBarText) { _, newValue in
            scheduleSuggestions(for: newValue)
        }
        .onChange(of: isFocused) { _, focused in
            if focused {
                scheduleSuggestions(for: tab.navigation.addressBarText)
            } else {
                // Keep list briefly so taps register, then clear.
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 180_000_000)
                    if !isFocused {
                        suggestions = []
                    }
                }
            }
        }
        .onDisappear {
            suggestionTask?.cancel()
        }
    }

    private var suggestionList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { item in
                Button {
                    applySuggestion(item)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: iconName(for: item.source))
                            .font(.footnote)
                            .foregroundStyle(accent)
                            .frame(width: 18)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.text)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            if let host = item.url?.host {
                                Text(host)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            } else if item.source == .remote {
                                Text("Search with \(searchEngine.displayName)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if item.id != suggestions.last?.id {
                    Divider().padding(.leading, 40)
                }
            }
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: OrielTheme.controlRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .zIndex(20)
    }

    private func iconName(for source: SearchSuggestion.Source) -> String {
        switch source {
        case .history: "clock"
        case .bookmark: "bookmark"
        case .remote: "magnifyingglass"
        }
    }

    private func applySuggestion(_ item: SearchSuggestion) {
        if let url = item.url {
            tab.navigation.addressBarText = url.absoluteString
            tab.load(url)
        } else {
            tab.navigation.addressBarText = item.text
            tab.submitAddressBar()
        }
        suggestions = []
        isFocused = false
    }

    private func scheduleSuggestions(for raw: String) {
        suggestionTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        // Skip suggestions when the field already looks like a full URL the user is editing.
        if trimmed.contains("://") || (trimmed.contains(".") && trimmed.contains("/")) {
            suggestions = []
            return
        }

        suggestionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard !Task.isCancelled else { return }
            let results = await environment.searchSuggestions.suggestions(
                for: trimmed,
                engine: searchEngine,
                history: environment.history,
                bookmarks: environment.bookmarks
            )
            guard !Task.isCancelled else { return }
            suggestions = results
        }
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
        if URLParser.isStartPage(tab.navigation.url) {
            return accent
        }
        if tab.navigation.url?.scheme?.lowercased() == "https" {
            return accent.opacity(0.85)
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
