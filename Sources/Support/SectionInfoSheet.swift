import SwiftUI

/// Short "what is this screen" sheet for tabs backed by the official portal.
/// Flags the feature as beta and links to the matching portal pages as a fallback.
struct SectionInfoSheet: View {
    struct PortalLink: Identifiable {
        let title: LocalizedStringKey
        let path: String
        var id: String { path }
    }

    @Environment(\.dismiss) private var dismiss
    let title: LocalizedStringKey
    let summary: LocalizedStringKey
    let links: [PortalLink]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(summary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Beta", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.orange)
                        Text(
                            "This section uses an unofficial connection to the official portal. It is in beta and may fail if the portal changes or cannot be reached. If something goes wrong, finish the task in the official portal."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))

                    ForEach(links) { link in
                        Link(destination: CaseroClient.baseURL.appendingPathComponent(link.path)) {
                            HStack {
                                Spacer()
                                Label(link.title, systemImage: "safari")
                                Spacer()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
