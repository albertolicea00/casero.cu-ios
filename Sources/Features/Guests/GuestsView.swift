import SwiftUI

struct GuestsView: View {
    @EnvironmentObject private var appState: AppState
    private let client: CaseroClient
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: GuestsViewModel
    @State private var isDateFilterPresented = false
    @State private var pendingFrom = Date()
    @State private var pendingTo = Date()

    init(client: CaseroClient, settings: AppSettings) {
        self.client = client
        self.settings = settings
        _viewModel = StateObject(wrappedValue: GuestsViewModel(client: client, settings: settings))
    }

    private static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yy"
        formatter.timeZone = PortalDates.timeZone
        return formatter
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !appState.isSignedIn {
                    Text("Sign in on Register to refresh portal data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                if viewModel.isOffline {
                    Label(offlineCaption, systemImage: "icloud.slash")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Name or passport", text: $viewModel.searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if !viewModel.searchText.isEmpty {
                            Button {
                                viewModel.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                            }
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        pendingFrom = viewModel.from
                        pendingTo = viewModel.to
                        isDateFilterPresented = true
                    } label: {
                        Image(systemName: "calendar")
                            .frame(width: 44, height: 44)
                            .background(
                                Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .accessibilityLabel("Date range")
                }
                .padding(.horizontal)
                .padding(.top, 8)

                if let message = viewModel.errorMessage, !viewModel.guests.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }

                HStack(spacing: 10) {
                    Picker("Segment", selection: $viewModel.segment) {
                        ForEach(GuestsViewModel.Segment.allCases) { segment in
                            Text(LocalizedStringKey(segment.rawValue)).tag(segment)
                        }
                    }
                    .pickerStyle(.segmented)

                    Menu {
                        Picker("Sort order", selection: $viewModel.sortOrder) {
                            ForEach(GuestsViewModel.SortOrder.allCases) { order in
                                Text(LocalizedStringKey(order.rawValue)).tag(order)
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                            .frame(width: 44, height: 36)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Sort guests")
                }
                .padding(.horizontal)
                .padding(.top, 12)

                content
            }
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Guests")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .accessibilityLabel("Reload guests")
                    .disabled(viewModel.isLoading || !appState.isSignedIn)

                    Button {
                        Task { await appState.signOutCompletely() }
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .accessibilityLabel("Sign out")
                    .disabled(appState.isSigningOut)
                }
            }
            .sheet(isPresented: $isDateFilterPresented) {
                GuestDateRangeSheet(
                    from: $pendingFrom,
                    to: $pendingTo,
                    defaultDays: settings.defaultGuestRangeDays,
                    isLoading: viewModel.isLoading
                ) {
                    viewModel.from = pendingFrom
                    viewModel.to = pendingTo
                    isDateFilterPresented = false
                    Task { await viewModel.reload() }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            await viewModel.loadFromCache()
            if appState.isSignedIn { await viewModel.reload() }
        }
        .onChange(of: viewModel.guests.count) { count in appState.hasCachedGuests = count > 0 }
        .onChange(of: settings.cacheTTL) { _ in Task { await viewModel.loadFromCache() } }
        .onChange(of: settings.defaultGuestRangeDays) { _ in
            viewModel.applyDefaultRange()
            if appState.isSignedIn { Task { await viewModel.reload() } }
        }
        .onChange(of: viewModel.isSessionExpired) { expired in
            guard expired else { return }
            Task {
                await appState.reportSessionExpired()
                viewModel.acknowledgeSessionExpired()
            }
        }
    }

    private var offlineCaption: String {
        if let lastFetched = viewModel.lastFetched {
            return String(localized: "Showing cached data from \(Self.displayDate.string(from: lastFetched)).")
        }
        return String(localized: "Showing cached data.")
    }

    @ViewBuilder
    private var content: some View {
        let guests = viewModel.filteredGuests
        if guests.isEmpty {
            if viewModel.isLoading {
                ProgressView().frame(maxHeight: .infinity)
            } else if let message = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Text(message).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.reload() } }
                        .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                Text("No guests in this range.").foregroundStyle(.secondary).frame(maxHeight: .infinity)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(guests) { guest in
                        NavigationLink {
                            GuestDetailView(guest: guest, client: client, settings: settings)
                        } label: {
                            GuestRow(guest: guest, dateFormatter: Self.displayDate)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .refreshable { if appState.isSignedIn { await viewModel.reload() } }
        }
    }
}

private struct GuestDateRangeSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var from: Date
    @Binding var to: Date
    let defaultDays: Int
    let isLoading: Bool
    let onApply: () -> Void

    private var rangeLength: Int {
        max(0, PortalDates.calendar.dateComponents([.day], from: from, to: to).day ?? 0)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Default guest range: last \(defaultDays) days. Change this in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(alignment: .center, spacing: 8) {
                    datePicker("From", selection: $from)
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    datePicker("To", selection: $to)
                }
                .padding(12)
                .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))

                if rangeLength > 180 {
                    Label("Large date ranges may take longer to load.", systemImage: "clock")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                Button(action: onApply) {
                    if isLoading {
                        ProgressView().frame(maxWidth: .infinity, minHeight: 48)
                    } else {
                        Text("Apply dates").frame(maxWidth: .infinity, minHeight: 48)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(from > to || isLoading)

                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Date range")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func datePicker(_ title: LocalizedStringKey, selection: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            DatePicker(title, selection: selection, displayedComponents: .date)
                .datePickerStyle(.compact)
                .labelsHidden()
                .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct GuestRow: View {
    let guest: Guest
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(guest.fullName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Label("Passport/ID: \(guest.identificador)", systemImage: "person.text.rectangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let nationality = guest.nationality {
                    HStack(spacing: 5) {
                        Image(systemName: "globe")
                        Text("Nationality: \(nationality)")
                        if let flag = NationalityFlag.emoji(for: nationality) {
                            Text(flag)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }

            if guest.checkIn != nil || guest.checkOut != nil {
                HStack(alignment: .top, spacing: 8) {
                    stayDate(title: "Check-in", date: guest.checkIn)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 19)
                    stayDate(title: "Check-out", date: guest.checkOut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let duration = stayDuration, let checkIn = guest.checkIn {
                    HStack(spacing: 3) {
                        Label("Stay: \(duration)", systemImage: "moon.stars")
                        Text("(")
                        Text(checkIn, style: .relative)
                        Text(")")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func stayDate(title: LocalizedStringKey, date: Date?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            if let date {
                Text(dateFormatter.string(from: date))
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(.primary)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stayDuration: String? {
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
}

private enum NationalityFlag {
    private static let aliases: [String: String] = [
        "CUBA": "CU",
        "ESPANA": "ES",
        "ESTADOS UNIDOS DE AMERICA": "US",
        "ESTADOS UNIDOS": "US",
        "REINO UNIDO": "GB",
        "INGLATERRA": "GB",
        "RUSIA": "RU",
        "PAISES BAJOS": "NL",
        "HOLANDA": "NL",
        "REPUBLICA CHECA": "CZ",
        "COREA DEL SUR": "KR",
        "COREA DEL NORTE": "KP",
        "REPUBLICA DOMINICANA": "DO",
        "COSTA RICA": "CR",
        "PUERTO RICO": "PR",
        "VENEZUELA": "VE",
        "MEXICO": "MX",
        "CANADA": "CA",
        "ALEMANIA": "DE",
        "FRANCIA": "FR",
        "ITALIA": "IT",
        "PORTUGAL": "PT",
        "BRASIL": "BR",
        "ARGENTINA": "AR",
        "CHILE": "CL",
        "COLOMBIA": "CO",
        "PANAMA": "PA",
        "JAPON": "JP",
        "CHINA": "CN",
        "AUSTRALIA": "AU",
    ]

    private static let localizedCodes: [String: String] = {
        let locales = [Locale(identifier: "es"), Locale(identifier: "en")]
        var result: [String: String] = [:]
        for region in Locale.Region.isoRegions {
            let regionCode = region.identifier
            guard regionCode.count == 2 else { continue }
            for locale in locales {
                if let regionName = locale.localizedString(forRegionCode: regionCode) {
                    result[fold(regionName)] = regionCode
                }
            }
        }
        return result
    }()

    static func emoji(for nationality: String?) -> String? {
        guard let nationality else { return nil }
        let normalized = fold(nationality)
        let code = aliases[normalized] ?? localizedCodes[normalized]
        guard let code, code.count == 2 else { return nil }
        let scalars = code.uppercased().unicodeScalars.compactMap { Unicode.Scalar(127_397 + $0.value) }
        return String(String.UnicodeScalarView(scalars))
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "es"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
