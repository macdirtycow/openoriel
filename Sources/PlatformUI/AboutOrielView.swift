import SwiftUI

struct AboutOrielView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                OrielMark(size: 72, showsWordmark: false)

                Text(BrowserConstants.productName)
                    .font(.largeTitle.weight(.bold))

                Text("A native browser for Apple platforms.")
                    .foregroundStyle(.secondary)

                VStack(spacing: 8) {
                    Text("Official website")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link(BrowserConstants.productWebsiteHost, destination: BrowserConstants.productWebsiteURL)
                        .font(.headline)

                    Text("Made by \(BrowserConstants.publisherName)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    Link(BrowserConstants.publisherName, destination: BrowserConstants.publisherURL)
                        .font(.footnote)
                }
                .padding(.top, 4)

                Text("Uses Apple’s WebKit framework. Privacy protections are limited by what WebKit and the OS expose.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: 480)
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
}
