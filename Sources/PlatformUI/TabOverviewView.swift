import SwiftUI

struct TabOverviewView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(environment.tabs.tabs) { tab in
                        tabCard(tab)
                    }
                }
                .padding()
            }
            .navigationTitle("Tabs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("New Tab") {
                            environment.tabs.createTab(select: true)
                            environment.wireTabPrivacyHooks()
                            dismiss()
                        }
                        Button("New Private Tab") {
                            environment.tabs.createPrivateTab(select: true)
                            environment.wireTabPrivacyHooks()
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New Tab")
                }
            }
        }
    }

    private func tabCard(_ tab: BrowserTab) -> some View {
        let isActive = tab.id == environment.tabs.activeTabID
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                if tab.isPrivate {
                    Image(systemName: "eyeglasses")
                        .foregroundStyle(.purple)
                        .accessibilityLabel("Private")
                }
                Text(tab.displayTitle)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                Spacer(minLength: 4)
                Button {
                    environment.tabs.closeTab(id: tab.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Tab")
            }

            Text(tab.restorableURL.host ?? tab.restorableURL.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .background(
            tab.isPrivate ? Color.purple.opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            environment.tabs.selectTab(id: tab.id)
            dismiss()
        }
    }
}
