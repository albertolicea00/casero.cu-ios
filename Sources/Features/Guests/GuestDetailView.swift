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
    @State private var isLoadingPhoto = false
    @State private var isLoadingCompanions = false
    @State private var didLoadCompanions = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                stayCard
                personalCard
                photoCard

                if !isCompanion {
                    companionsCard
                    NavigationLink {
                        PortalPageView(path: "Huespedes/HuespedesRegistrados", title: "Guest details")
                    } label: {
                        Label("View in official portal", systemImage: "arrow.up.right.square")
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(isCompanion ? "Companion details" : "Guest details")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: guest.id + (isCompanion ? "-companion" : "-guest")) {
            photo = await GuestPhotoService(client: client, settings: settings).cachedImage(
                for: guest, isCompanion: isCompanion)
        }
    }

    private var stayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stay timeline").font(.headline)
            StayDateLine(title: "Check-in", date: guest.checkIn, color: .accentColor)
            StayDateLine(title: "Check-out", date: guest.checkOut, color: .orange)
        }
        .guestCard()
    }

    private var personalCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Personal data").font(.headline)
            Text(guest.fullName).font(.title3.weight(.semibold)).textSelection(.enabled)
            LabeledContent("Passport/ID", value: guest.identificador)
                .textSelection(.enabled)
            if let nationality = guest.nationality {
                LabeledContent("Nationality", value: nationality)
            }
            if let date = guest.birthDate {
                LabeledContent("Birth date", value: PortalDates.display(date))
            }
        }
        .guestCard()
    }

    private var photoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photo").font(.headline)
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Guest photo")
            }
            if let photoError {
                Text(photoError).font(.caption).foregroundStyle(.red)
            }
            Button {
                Task { await loadPhoto() }
            } label: {
                if isLoadingPhoto {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label(photo == nil ? "Load photo" : "Reload photo", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isLoadingPhoto)
        }
        .guestCard()
    }

    private var companionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Companions").font(.headline)
                Spacer()
                if didLoadCompanions {
                    Text("\(companions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            if didLoadCompanions && companions.isEmpty && companionsError == nil {
                Text("No companions.").font(.subheadline).foregroundStyle(.secondary)
            }
            if !companions.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(companions.enumerated()), id: \.element.id) { index, companion in
                        CompanionSummary(guest: companion)
                        if index < companions.count - 1 {
                            Divider().padding(.leading, 12)
                        }
                    }
                }
                .background(Color(uiColor: .systemBackground).opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
            }
            if let companionsError {
                Text(companionsError).font(.caption).foregroundStyle(.red)
            }

            Button {
                Task { await loadCompanions() }
            } label: {
                if isLoadingCompanions {
                    ProgressView().frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    Label(
                        didLoadCompanions ? "Reload companions" : "Load companions",
                        systemImage: "arrow.clockwise"
                    )
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isLoadingCompanions || guest.stayId.isEmpty)
        }
        .guestCard()
    }

    private func loadPhoto() async {
        guard !isLoadingPhoto else { return }
        isLoadingPhoto = true
        photoError = nil
        defer { isLoadingPhoto = false }
        do {
            photo = try await GuestPhotoService(client: client, settings: settings).image(
                for: guest, isCompanion: isCompanion)
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch { photoError = error.localizedDescription }
    }

    private func loadCompanions() async {
        guard !isLoadingCompanions else { return }
        isLoadingCompanions = true
        companionsError = nil
        defer { isLoadingCompanions = false }
        do {
            companions = try await client.listCompanions(estanciaId: guest.stayId, pageSize: 100)
            didLoadCompanions = true
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch { companionsError = error.localizedDescription }
    }
}

private struct StayDateLine: View {
    let title: LocalizedStringKey
    let date: Date?
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 9, height: 9)
            Text(title).font(.subheadline.weight(.semibold))
            Spacer(minLength: 4)
            if let date {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(PortalDates.display(date)).font(.subheadline.monospacedDigit())
                    Text(date, style: .relative).font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("—").foregroundStyle(.secondary)
            }
        }
    }
}

private struct CompanionSummary: View {
    let guest: Guest

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(guest.fullName).font(.subheadline.weight(.semibold))
            Text("Passport/ID: \(guest.identificador)").font(.caption).foregroundStyle(.secondary)
            if let nationality = guest.nationality {
                Text("Nationality: \(nationality)").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                if let checkIn = guest.checkIn {
                    Label {
                        Text("Check-in: \(PortalDates.display(checkIn)) · ") + Text(checkIn, style: .relative)
                    } icon: {
                        Image(systemName: "arrow.right.to.line")
                    }
                }
                if let checkOut = guest.checkOut {
                    Label {
                        Text("Check-out: \(PortalDates.display(checkOut)) · ") + Text(checkOut, style: .relative)
                    } icon: {
                        Image(systemName: "arrow.left.to.line")
                    }
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
            .labelStyle(.titleAndIcon)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
    }
}

extension View {
    fileprivate func guestCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}
