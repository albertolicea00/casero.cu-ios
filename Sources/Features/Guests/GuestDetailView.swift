import SwiftUI

struct GuestDetailView: View {
    @EnvironmentObject private var appState: AppState
    let guest: Guest
    let client: CaseroClient
    let settings: AppSettings
    var isCompanion = false
    @State private var photo: UIImage?
    @State private var photoError: String?
    @State private var companions: [Guest] = []
    @State private var companionsError: String?
    @State private var isLoading = false
    @State private var didLoadCompanions = false

    var body: some View {
        List {
            Section("Personal data") {
                Text(guest.fullName).font(.headline).textSelection(.enabled)
                Text(guest.identificador).textSelection(.enabled)
                if let nationality = guest.nationality { Text(nationality) }
                if let date = guest.birthDate {
                    LabeledContent("Birth date", value: PortalDates.display(date))
                }
                if let date = guest.checkIn {
                    LabeledContent("Check-in", value: PortalDates.display(date))
                }
                if let date = guest.checkOut {
                    LabeledContent("Check-out", value: PortalDates.display(date))
                }
            }
            Section("Photo") {
                if let photo {
                    Image(uiImage: photo).resizable().scaledToFit().frame(maxHeight: 240)
                        .accessibilityLabel("Guest photo")
                }
                if let photoError { Text(photoError).font(.caption).foregroundStyle(.secondary) }
                Button("Load photo") { Task { await loadPhoto() } }.disabled(isLoading)
            }
            if !isCompanion {
                Section("Companions") {
                    ForEach(companions) { companion in
                        NavigationLink {
                            GuestDetailView(guest: companion, client: client, settings: settings, isCompanion: true)
                        } label: {
                            Text(companion.fullName)
                        }
                    }
                    if didLoadCompanions && companions.isEmpty && companionsError == nil { Text("No companions.") }
                    if let companionsError { Text(companionsError).foregroundStyle(.red) }
                    Button("Load companions") { Task { await loadCompanions() } }
                        .disabled(isLoading || guest.stayId.isEmpty)
                    NavigationLink("View in official portal") {
                        PortalPageView(path: "Huespedes/HuespedesRegistrados", title: "Companions")
                    }
                }
            }
            if isLoading { ProgressView().accessibilityLabel("Loading") }
        }
        .navigationTitle("Guest details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadPhoto() async {
        guard !isLoading else { return }
        isLoading = true
        photoError = nil
        defer { isLoading = false }
        do {
            photo = try await GuestPhotoService(client: client, settings: settings).image(
                for: guest, isCompanion: isCompanion)
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch { photoError = error.localizedDescription }
    }

    private func loadCompanions() async {
        guard !isLoading else { return }
        isLoading = true
        companionsError = nil
        defer { isLoading = false }
        do {
            companions = try await client.listCompanions(estanciaId: guest.stayId, pageSize: 100)
            didLoadCompanions = true
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch { companionsError = error.localizedDescription }
    }
}
