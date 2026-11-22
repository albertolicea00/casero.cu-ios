import SwiftUI

/// The host's portal account, read-only. Password changes happen on the official profile page.
struct PortalProfileSheet: View {
    private enum LoadState {
        case loading
        case loaded(PortalProfile)
        case failed(String)
    }

    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    let client: CaseroClient
    @State private var state = LoadState.loading

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your account in the official portal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    content

                    Link(destination: CaseroClient.baseURL.appendingPathComponent("Cuenta/Perfil")) {
                        HStack {
                            Spacer()
                            Label("Change password in the portal", systemImage: "safari")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("Portal Profile Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: appState.isSignedIn) { await load() }
            .refreshable { await load() }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        if !appState.isSignedIn {
            Label("Sign in to see your portal profile.", systemImage: "person.crop.circle.badge.exclamationmark")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        } else {
            switch state {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            case .failed(let error):
                VStack(alignment: .leading, spacing: 10) {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                    Button("Retry") { Task { await load() } }
                    Link(destination: CaseroClient.baseURL.appendingPathComponent("Cuenta/Perfil")) {
                        Label("Check it on the official website", systemImage: "safari")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            case .loaded(let profile):
                InputCard {
                    let rows = Self.rows(for: profile)
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { Divider() }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(verbatim: row.value)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
        }
    }

    private static func rows(for profile: PortalProfile) -> [(label: LocalizedStringKey, value: String)] {
        [
            ("Name", profile.fullName),
            ("Identity card (CI)", profile.identityNumber),
            ("Username", profile.username),
            ("Province", profile.province),
            ("Municipality", profile.municipality),
            ("Address", profile.address),
        ].filter { !$0.value.isEmpty }
    }

    private func load() async {
        guard appState.isSignedIn else { return }
        state = .loading
        do {
            state = .loaded(try await client.fetchProfile())
        } catch is CancellationError {
            return
        } catch PortalError.sessionExpired {
            state = .failed(PortalError.sessionExpired.localizedDescription)
            await appState.reportSessionExpired()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}
