import SwiftUI

struct GuestsView: View {
    @EnvironmentObject private var appState: AppState
    private let client: CaseroClient
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: GuestsViewModel
    @State private var isDateFilterPresented = false
    @State private var isLoginPresented = false
    @State private var pendingFrom = Date()
    @State private var pendingTo = Date()
    @State private var companionCounts: [String: Int] = [:]

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
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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
            .sheet(isPresented: $isLoginPresented) {
                LoginView(client: client, settings: settings)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
                if !appState.isSignedIn {
                    HStack {
                        Spacer()
                        Button {
                            isLoginPresented = true
                        } label: {
                            Label("Sign in", systemImage: "person.crop.circle.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
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
        .onChange(of: appState.isSignedIn) { signedIn in
            if signedIn {
                isLoginPresented = false
                Task { await viewModel.reload() }
            }
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
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundStyle(.orange)
                    Text(message).foregroundStyle(.red).multilineTextAlignment(.center)
                    Button("Retry") { Task { await viewModel.reload() } }
                        .buttonStyle(.bordered)
                }
                .padding()
                .frame(maxHeight: .infinity)
            } else {
                VStack(spacing: 10) {
                    Image(systemName: "person.2")
                        .font(.system(size: 38, weight: .regular))
                        .foregroundStyle(.tertiary)
                    Text("No guests in this range.")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(guests) { guest in
                        NavigationLink {
                            GuestDetailView(
                                guest: guest,
                                client: client,
                                settings: settings,
                                onCompanionsLoaded: { count in companionCounts[guest.id] = count }
                            )
                        } label: {
                            GuestRow(
                                guest: guest,
                                dateFormatter: Self.displayDate,
                                companionCount: companionCounts[guest.id]
                            )
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
    let companionCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(guest.fullName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.headline)
                .foregroundStyle(.primary)
                if let companionLine {
                    Text(companionLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if guest.checkIn != nil || guest.checkOut != nil {
                HStack(alignment: .center, spacing: 8) {
                    stayDate(title: "Check-in", date: guest.checkIn)
                    Image(systemName: "arrow.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 18)
                    stayDate(title: "Check-out", date: guest.checkOut)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let duration = GuestStayText.duration(for: guest) {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.stars")
                        Text(String.localizedStringWithFormat(String(localized: "Stay: %@"), duration))
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                }
                if let checkIn = guest.checkIn {
                    Text(GuestStayText.age(of: checkIn))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }

    private var companionLine: String? {
        guard let companionCount, companionCount > 0 else { return nil }
        return companionCount == 1
            ? String(localized: "+ 1 companion")
            : String(localized: "+ \(companionCount) companions")
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

}

enum NationalityFlag {
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
