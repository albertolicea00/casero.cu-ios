import SwiftUI

/// Lists the host's registered phones and e-mails. Changes happen on the official page.
struct CommunicationChannelsSheet: View {
    private enum LoadState {
        case loading
        case loaded([CommunicationChannel])
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
                    Text("Phones and emails registered in the official portal for alternative communication.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)

                    content

                    Link(destination: CaseroClient.baseURL.appendingPathComponent("ViasComunicacion")) {
                        HStack {
                            Spacer()
                            Label("Manage phones and emails", systemImage: "safari")
                            Spacer()
                        }
                    }
                    .buttonStyle(.bordered)

                    Text("Adding or removing channels is done in the official portal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding()
            }
            .navigationTitle("Communication channels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task(id: appState.isSignedIn) { await load() }
            .refreshable { await load() }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private var content: some View {
        if !appState.isSignedIn {
            message("Sign in to see your registered channels.", systemImage: "person.crop.circle.badge.exclamationmark")
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
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            case .loaded(let channels) where channels.isEmpty:
                message("No communication channels registered.", systemImage: "tray")
            case .loaded(let channels):
                InputCard {
                    ForEach(Array(channels.enumerated()), id: \.offset) { index, channel in
                        if index > 0 { Divider() }
                        Label(channel.value, systemImage: channel.isPhone ? "phone.fill" : "envelope.fill")
                            .textSelection(.enabled)
                            .padding(.vertical, 12)
                    }
                }
            }
        }
    }

    private func message(_ text: LocalizedStringKey, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        guard appState.isSignedIn else { return }
        state = .loading
        do {
            state = .loaded(try await client.listCommunicationChannels())
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
