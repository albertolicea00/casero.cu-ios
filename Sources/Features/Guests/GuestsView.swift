import SwiftUI

struct GuestsView: View {
    @EnvironmentObject private var appState: AppState
    private let client: CaseroClient
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: GuestsViewModel
    @State private var isDateFilterPresented = false
    @State private var pendingFrom = Date()
    @State private var pendingTo = Date()
    @State private var companionCounts: [String: Int] = [:]
    @State private var visibleGuestID: String?
    @State private var isScrubbingGuests = false

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

    private static let lastUpdatedDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = PortalDates.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private static let monthTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = PortalDates.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM yyyy")
        return formatter
    }()

    private struct GuestMonth: Identifiable {
        let month: Date?
        var guests: [Guest]
        var id: String { month.map { String($0.timeIntervalSince1970) } ?? "unknown" }
    }

    private func groupedByCheckInMonth(_ guests: [Guest]) -> [GuestMonth] {
        var groups: [GuestMonth] = []
        for guest in guests {
            let month = guest.checkIn.flatMap { PortalDates.calendar.dateInterval(of: .month, for: $0)?.start }
            if groups.last?.month == month {
                groups[groups.count - 1].guests.append(guest)
            } else {
                groups.append(GuestMonth(month: month, guests: [guest]))
            }
        }
        return groups
    }

    private var nationalityNamesByCode: [String: String] {
        let names = Dictionary(grouping: viewModel.guests.compactMap { guest -> (String, String)? in
            guard let code = guest.nationalityCode?.trimmingCharacters(in: .whitespacesAndNewlines),
                !code.isEmpty,
                let nationality = guest.nationality?.trimmingCharacters(in: .whitespacesAndNewlines),
                !nationality.isEmpty,
                NationalityFlag.emoji(for: nationality) != nil
            else { return nil }
            return (code, nationality)
        }, by: { $0.0 })
        return names.compactMapValues { entries in
            let countries = Set(entries.compactMap { NationalityFlag.emoji(for: $0.1) })
            return countries.count == 1 ? entries.first?.1 : nil
        }
    }

    var body: some View {
        NavigationStack {
            content
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Guests")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
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
        return String(localized: "Showing cached data.")
    }

    private var searchAndFilterControls: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.body).foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("Name or passport", text: $viewModel.searchText)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .submitLabel(.search)
                    .frame(maxWidth: .infinity, minHeight: 44)
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))

            Menu {
                Picker("Sort order", selection: $viewModel.sortOrder) {
                    ForEach(GuestsViewModel.SortOrder.allCases) { order in
                        Text(LocalizedStringKey(order.rawValue)).tag(order)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
                    .frame(width: 36, height: 44)
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .buttonStyle(.plain)
            .tint(Color(uiColor: .tertiaryLabel))
            .accessibilityLabel("Sort guests")
        }
    }

    // Lives inside the ScrollView rather than in a top safe-area inset: an inset
    // above the scroll view throws off the large title's initial offset and it
    // starts hidden until the user pulls down.
    private var segmentControls: some View {
        HStack(spacing: 10) {
            Picker("Segment", selection: $viewModel.segment) {
                ForEach(GuestsViewModel.Segment.allCases) { segment in
                    Text(LocalizedStringKey(segment.rawValue)).tag(segment)
                }
            }
            .pickerStyle(.segmented)

            Button {
                pendingFrom = viewModel.from
                pendingTo = viewModel.to
                isDateFilterPresented = true
            } label: {
                Image(systemName: "calendar")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                    .frame(width: 44, height: 36)
            }
            .buttonStyle(.plain)
            .tint(Color(uiColor: .tertiaryLabel))
            .accessibilityLabel("Date range")
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if viewModel.isLoading {
            ProgressView()
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
        } else {
            VStack(spacing: 10) {
                Image(systemName: "person.2")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(.tertiary)
                Text("No guests in this range.")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // A single ScrollView is kept in every state: swapping it for a plain view
    // (e.g. switching to an empty segment) makes the navigation bar lose track
    // of it and the large title stops showing.
    private var content: some View {
        let guests = viewModel.filteredGuests
        let months = groupedByCheckInMonth(guests)
        let knownNationalities = nationalityNamesByCode
        return ScrollViewReader { scrollProxy in
                ScrollView {
                    VStack(spacing: 8) {
                        segmentControls
                        searchAndFilterControls
                        if let message = viewModel.errorMessage, !guests.isEmpty {
                            Text(message).font(.caption).foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if viewModel.isOffline {
                            Label(offlineCaption, systemImage: "icloud.slash")
                                .font(.caption).foregroundStyle(.orange)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let lastFetched = viewModel.lastFetched {
                            Text(String.localizedStringWithFormat(
                                String(localized: "Last updated: %@"),
                                Self.lastUpdatedDate.string(from: lastFetched)
                            ))
                            .font(.caption).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if guests.isEmpty {
                        emptyState
                            .frame(maxWidth: .infinity, minHeight: 320)
                    } else {
                    LazyVStack(spacing: 10, pinnedViews: [.sectionHeaders]) {
                        ForEach(months) { group in
                        Section {
                            ForEach(group.guests) { guest in
                                NavigationLink {
                                    GuestDetailView(
                                        guest: guest,
                                        client: client,
                                        settings: settings,
                                        nationalityNamesByCode: knownNationalities,
                                        onCompanionsLoaded: { count in companionCounts[guest.id] = count }
                                    )
                                } label: {
                                    GuestRow(
                                        guest: guest,
                                        dateFormatter: Self.displayDate,
                                        companionCount: companionCounts[guest.id],
                                        nationalityNamesByCode: knownNationalities
                                    )
                                }
                                .buttonStyle(.plain)
                                .background {
                                    GeometryReader { geometry in
                                        Color.clear.preference(
                                            key: GuestRowPositions.self,
                                            value: [guest.id: geometry.frame(in: .named("guestList")).minY]
                                        )
                                    }
                                }
                                .id(guest.id)
                            }
                        } header: {
                            Text(group.month.map { Self.monthTitle.string(from: $0) } ?? String(localized: "Unknown date"))
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .systemBackground))
                        }
                    }
                    }
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                    }
                }
                .coordinateSpace(name: "guestList")
                .scrollIndicators(.hidden)
                .onPreferenceChange(GuestRowPositions.self) { positions in
                    guard !isScrubbingGuests else { return }
                    let current = positions.filter { $0.value <= 30 }.max { $0.value < $1.value }
                        ?? positions.min { $0.value < $1.value }
                    if let current { visibleGuestID = current.key }
                }
                .overlay(alignment: .trailing) {
                    if guests.count > 1 {
                        guestScrubber(guests: guests) { id in
                            visibleGuestID = id
                            scrollProxy.scrollTo(id, anchor: .top)
                        }
                    }
                }
                .refreshable { if appState.isSignedIn { await viewModel.reload() } }
            }
    }

    private func guestScrubber(guests: [Guest], onSelect: @escaping (String) -> Void) -> some View {
        GeometryReader { geometry in
            let index = guests.firstIndex { $0.id == visibleGuestID } ?? 0
            let travel = max(0, geometry.size.height - 36)
            let position = travel * CGFloat(index) / CGFloat(guests.count - 1)

            ZStack(alignment: .topTrailing) {
                Capsule()
                    .fill(Color(uiColor: .separator))
                    .frame(width: 3)
                    .padding(.vertical, 18)
                    .padding(.trailing, 12)
                Capsule()
                    .fill(Color(uiColor: .secondaryLabel))
                    .frame(width: 7, height: 36)
                    .padding(.trailing, 10)
                    .offset(y: position)
                if isScrubbingGuests {
                    Text(guests[index].checkIn.map { Self.monthTitle.string(from: $0) } ?? "—")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .secondarySystemBackground), in: Capsule())
                        .shadow(color: .black.opacity(0.15), radius: 5, y: 2)
                        .offset(x: -44, y: min(position, max(0, geometry.size.height - 64)))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isScrubbingGuests = true
                        let fraction = min(max(value.location.y / geometry.size.height, 0), 1)
                        let selected = min(guests.count - 1, Int((fraction * CGFloat(guests.count - 1)).rounded()))
                        if guests[selected].id != visibleGuestID { onSelect(guests[selected].id) }
                    }
                    .onEnded { _ in isScrubbingGuests = false }
            )
        }
        .frame(width: 44)
        .padding(.trailing, 8)
        .accessibilityLabel("Scroll by date")
        .accessibilityAdjustableAction { direction in
            let index = guests.firstIndex { $0.id == visibleGuestID } ?? 0
            switch direction {
            case .increment: onSelect(guests[min(index + 1, guests.count - 1)].id)
            case .decrement: onSelect(guests[max(index - 1, 0)].id)
            @unknown default: break
            }
        }
    }
}

private struct GuestRowPositions: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
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
    let nationalityNamesByCode: [String: String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(guest.fullName)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let nationality = guest.displayNationality(
                        isCompanion: false, knownNamesByCode: nationalityNamesByCode),
                        let flag = NationalityFlag.emoji(for: nationality)
                    {
                        Text(flag)
                            .accessibilityLabel("Nationality: \(nationality)")
                    }
                }
                .font(.headline)
                .foregroundStyle(.primary)
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
            }
            if GuestStayText.duration(for: guest) != nil || companionLine != nil {
                HStack(spacing: 8) {
                    if let duration = GuestStayText.duration(for: guest) {
                        HStack(spacing: 6) {
                            Image(systemName: "moon.stars")
                            Text(String.localizedStringWithFormat(String(localized: "Stay: %@"), duration))
                        }
                    }
                    Spacer(minLength: 8)
                    if let companionLine {
                        Text(companionLine)
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
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
