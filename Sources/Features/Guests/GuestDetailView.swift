import SwiftUI

struct GuestDetailView: View {
    @EnvironmentObject private var appState: AppState
    let guest: Guest
    let client: CaseroClient
    let settings: AppSettings
    var isCompanion = false
    var onCompanionsLoaded: ((Int) -> Void)? = nil
    @State private var photo: UIImage?
    @State private var photoError: String?
    @State private var companions: [Guest] = []
    @State private var companionsError: String?
    @State private var isLoadingPhoto = false
    @State private var isLoadingCompanions = false
    @State private var isLoadingCompanionPhotos = false
    @State private var didLoadCompanions = false
    @State private var companionPhotos: [String: UIImage] = [:]
    @State private var companionPhotoError: String?
    @State private var isNationalityTooltipVisible = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                sectionHeading("Personal data")
                personalCard
                photoAction

                sectionHeading("Stay timeline")
                stayCard

                if !isCompanion {
                    companionsSection
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground).ignoresSafeArea())
        .navigationTitle(isCompanion ? "Companion details" : "Guest details")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: guest.id + (isCompanion ? "-companion" : "-guest")) {
            let photoService = GuestPhotoService(client: client, settings: settings)
            photo = await photoService.cachedImage(for: guest, isCompanion: isCompanion)
            if photo == nil {
                Task { await loadPhoto() }
            }
            if !isCompanion {
                await restoreCachedCompanions()
            }
        }
    }

    private func sectionHeading(_ title: LocalizedStringKey) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
    }

    private var personalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                GuestAvatar(guest: guest, photo: photo, size: 58)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(guest.fullName)
                            .font(.title3.weight(.semibold))
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if let nationality = guest.nationality,
                            let flag = NationalityFlag.emoji(for: nationality)
                        {
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isNationalityTooltipVisible.toggle()
                                }
                            } label: {
                                Text(flag)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Nationality: \(nationality)")
                            .overlay(alignment: .bottomTrailing) {
                                if isNationalityTooltipVisible {
                                    Text(nationality)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.regularMaterial, in: Capsule())
                                        .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 1))
                                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                                        .fixedSize()
                                        .offset(y: 30)
                                        .zIndex(1)
                                }
                            }
                            .task(id: isNationalityTooltipVisible) {
                                guard isNationalityTooltipVisible else { return }
                                try? await Task.sleep(nanoseconds: 1_800_000_000)
                                guard !Task.isCancelled else { return }
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    isNationalityTooltipVisible = false
                                }
                            }
                        }
                    }
                    Text("Passport/ID: \(guest.identificador)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
            registrationIdentifiers
        }
        .guestCard()
    }

    private var registrationIdentifiers: some View {
        HStack {
            HStack(spacing: 3) {
                Text("Stay ID")
                    .foregroundStyle(.secondary)
                Text(":")
                    .foregroundStyle(.secondary)
                Text(guest.stayId)
                    .fontWeight(.bold)
                    .textSelection(.enabled)
            }
            .font(.caption)
            if isCompanion {
                Spacer()
                HStack(spacing: 3) {
                    Text("ID")
                        .foregroundStyle(.secondary)
                    Text(":")
                        .foregroundStyle(.secondary)
                    Text(guest.companionId ?? "--")
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                }
                .font(.caption)
            }
        }
    }

    private var photoAction: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button {
                Task { await loadPhoto(forceRefresh: true) }
            } label: {
                Group {
                    if isLoadingPhoto {
                        ProgressView()
                    } else {
                        Label(photo == nil ? "Load photo" : "Reload photo", systemImage: "arrow.clockwise")
                    }
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .disabled(isLoadingPhoto)
            if let photoError {
                Text(photoError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.trailing)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 5)
    }

    private var stayCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            StayTimeline(guest: guest)
            if let duration = GuestStayText.duration(for: guest) {
                Divider()
                Label(
                    String.localizedStringWithFormat(String(localized: "Stay: %@"), duration), systemImage: "moon.stars"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .guestCard()
    }

    private var companionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                sectionHeading("Companions")
                Spacer()
                if didLoadCompanions {
                    Text("\(companions.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }

            if didLoadCompanions && companions.isEmpty && companionsError == nil {
                Text("No companions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ForEach(companions) { companion in
                CompanionSummary(guest: companion, photo: companionPhotos[companion.id])
            }
            if !companions.isEmpty {
                HStack {
                    Spacer()
                    Button {
                        Task { await loadCompanionPhotos(onlyIfMissing: false, forceRefresh: true) }
                    } label: {
                        if isLoadingCompanionPhotos {
                            ProgressView()
                                .frame(minHeight: 36)
                        } else {
                            Label(
                                hasAllCompanionPhotos ? "Reload companion photos" : "Load companion photos",
                                systemImage: "arrow.clockwise"
                            )
                            .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(isLoadingCompanionPhotos)
                }
            }
            if let companionPhotoError {
                Text(companionPhotoError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let companionsError {
                Text(companionsError).font(.caption).foregroundStyle(.red)
            }
            Button {
                Task { await loadCompanions() }
            } label: {
                if isLoadingCompanions {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    Text(didLoadCompanions ? "Reload companions" : "Load companions")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isLoadingCompanions || guest.stayId.isEmpty)
        }
    }

    private var hasAllCompanionPhotos: Bool {
        !companions.isEmpty && companions.allSatisfy { companionPhotos[$0.id] != nil }
    }

    private func loadPhoto(forceRefresh: Bool = false) async {
        guard !isLoadingPhoto else { return }
        isLoadingPhoto = true
        photoError = nil
        defer { isLoadingPhoto = false }
        do {
            photo = try await GuestPhotoService(client: client, settings: settings).image(
                for: guest, isCompanion: isCompanion, forceRefresh: forceRefresh)
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch {
            photoError = error.localizedDescription
        }
    }

    private func loadCompanions() async {
        guard !isLoadingCompanions else { return }
        isLoadingCompanions = true
        companionsError = nil
        defer { isLoadingCompanions = false }
        do {
            companions = try await client.listCompanions(estanciaId: guest.stayId, pageSize: 100)
            didLoadCompanions = true
            companionPhotos = [:]
            await GuestCache.shared.saveCompanions(companions, for: guest.stayId)
            onCompanionsLoaded?(companions.count)
            await loadCompanionPhotos(onlyIfMissing: true)
        } catch PortalError.sessionExpired {
            await appState.reportSessionExpired()
        } catch {
            companionsError = error.localizedDescription
        }
    }

    private func restoreCachedCompanions() async {
        guard !guest.stayId.isEmpty,
            let snapshot = await GuestCache.shared.loadCompanions(for: guest.stayId)
        else { return }
        if await GuestCache.shared.isStale(snapshot, ttl: settings.cacheTTL.interval) {
            await GuestCache.shared.removeCompanions(for: guest.stayId)
            return
        }
        companions = snapshot.companions
        didLoadCompanions = true
        onCompanionsLoaded?(companions.count)
        await loadCompanionPhotos(onlyIfMissing: true)
    }

    private func loadCompanionPhotos(onlyIfMissing: Bool, forceRefresh: Bool = false) async {
        guard !isLoadingCompanionPhotos, !companions.isEmpty else { return }
        isLoadingCompanionPhotos = true
        companionPhotoError = nil
        defer { isLoadingCompanionPhotos = false }
        let photoService = GuestPhotoService(client: client, settings: settings)

        for companion in companions {
            if onlyIfMissing,
                let cachedPhoto = await photoService.cachedImage(for: companion, isCompanion: true)
            {
                companionPhotos[companion.id] = cachedPhoto
                continue
            }
            do {
                companionPhotos[companion.id] = try await photoService.image(
                    for: companion, isCompanion: true, forceRefresh: forceRefresh)
            } catch PortalError.sessionExpired {
                await appState.reportSessionExpired()
                return
            } catch {
                companionPhotoError = error.localizedDescription
            }
        }
    }
}

private struct StayTimeline: View {
    let guest: Guest

    var body: some View {
        VStack(spacing: 12) {
            dateRow(title: "Check-in", date: guest.checkIn, icon: "arrow.right.to.line", color: .accentColor)
            dateRow(title: "Check-out", date: guest.checkOut, icon: "arrow.left.to.line", color: .orange)
        }
    }

    private func dateRow(
        title: LocalizedStringKey,
        date: Date?,
        icon: String,
        color: Color
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if let date {
                    Text(PortalDates.display(date))
                        .font(.subheadline.monospacedDigit().weight(.medium))
                        .foregroundStyle(.primary)
                    Text(GuestStayText.age(of: date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct CompanionSummary: View {
    let guest: Guest
    let photo: UIImage?

    var body: some View {
        companionCard.guestCard()
    }

    private var companionCard: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 12) {
                GuestAvatar(guest: guest, photo: photo, size: 46)
                VStack(alignment: .leading, spacing: 5) {
                    Text(guest.fullName)
                        .font(.subheadline.weight(.semibold))
                        .textSelection(.enabled)
                    Text("Passport/ID: \(guest.identificador)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            Divider().padding(.vertical, 3)
            HStack(alignment: .top) {
                HStack(spacing: 3) {
                    Text("Stay ID")
                        .foregroundStyle(.secondary)
                    Text(":")
                        .foregroundStyle(.secondary)
                    Text(guest.stayId)
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                }
                .font(.caption)
                Spacer()
                HStack(spacing: 3) {
                    Text("ID")
                        .foregroundStyle(.secondary)
                    Text(":")
                        .foregroundStyle(.secondary)
                    Text(guest.companionId ?? "--")
                        .fontWeight(.bold)
                        .textSelection(.enabled)
                }
                .font(.caption)
            }
            if guest.checkIn != nil || guest.checkOut != nil {
                Divider().padding(.vertical, 3)
                StayTimeline(guest: guest)
                if let duration = GuestStayText.duration(for: guest) {
                    Label(
                        String.localizedStringWithFormat(String(localized: "Stay: %@"), duration),
                        systemImage: "moon.stars"
                    )
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

}

private struct GuestAvatar: View {
    let guest: Guest
    let photo: UIImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(initials)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .tertiarySystemFill))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityLabel(guest.fullName)
    }

    private var initials: String {
        let parts = guest.fullName.split(whereSeparator: \.isWhitespace)
        let first = parts.first?.prefix(1) ?? "?"
        let last = parts.dropFirst().last?.prefix(1) ?? ""
        return (String(first) + String(last)).uppercased()
    }
}

extension View {
    fileprivate func guestCard() -> some View {
        padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

enum GuestStayText {
    static func duration(for guest: Guest) -> String? {
        guard let checkIn = guest.checkIn, let checkOut = guest.checkOut else { return nil }
        let count = max(
            0,
            PortalDates.calendar.dateComponents(
                [.day],
                from: PortalDates.calendar.startOfDay(for: checkIn),
                to: PortalDates.calendar.startOfDay(for: checkOut)
            ).day ?? 0
        )
        return count == 1 ? String(localized: "1 night") : String(localized: "\(count) nights")
    }

    static func age(of date: Date, relativeTo now: Date = .now) -> String {
        let calendar = PortalDates.calendar
        let date = calendar.startOfDay(for: date)
        let today = calendar.startOfDay(for: now)
        let isFuture = date > today
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: isFuture ? today : date,
            to: isFuture ? date : today
        )

        var units: [String] = []
        if let years = components.year, years > 0 {
            units.append(years == 1 ? String(localized: "1 year") : String(localized: "\(years) years"))
        }
        if let months = components.month, months > 0 {
            units.append(months == 1 ? String(localized: "1 month") : String(localized: "\(months) months"))
        }
        if let days = components.day, days > 0 {
            units.append(days == 1 ? String(localized: "1 day") : String(localized: "\(days) days"))
        }

        guard !units.isEmpty else { return String(localized: "Today") }
        let duration = ListFormatter.localizedString(byJoining: units)
        let format = String(localized: isFuture ? "In %@" : "%@ ago")
        return String.localizedStringWithFormat(format, duration)
    }

}
