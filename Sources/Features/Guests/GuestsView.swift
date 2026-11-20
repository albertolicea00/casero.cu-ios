import SwiftUI

struct GuestsView: View {
    @EnvironmentObject private var appState: AppState
    private let client: CaseroClient
    @ObservedObject private var settings: AppSettings
    @StateObject private var viewModel: GuestsViewModel

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

                DisclosureGroup("Date range") {
                    DatePicker("From", selection: $viewModel.from, displayedComponents: .date)
                    DatePicker("To", selection: $viewModel.to, displayedComponents: .date)
                    Button("Apply dates") { Task { await viewModel.reload() } }
                        .accessibilityLabel("Reload guests")
                        .disabled(viewModel.isLoading || !appState.isSignedIn)
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
            .searchable(text: $viewModel.searchText, prompt: "Name or passport")
            .navigationTitle("Guests")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task { await viewModel.reload() }
                    } label: {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise").frame(minWidth: 44, minHeight: 44)
                        }
                    }
                    .accessibilityLabel("Reload guests")
                    .disabled(viewModel.isLoading || !appState.isSignedIn)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign out") {
                        Task { await appState.signOutCompletely() }
                    }
                }
            }
        }
        .task {
            await viewModel.loadFromCache()
            if appState.isSignedIn { await viewModel.reload() }
        }
        .onChange(of: viewModel.guests.count) { count in appState.hasCachedGuests = count > 0 }
        .onChange(of: settings.cacheTTL) { _ in Task { await viewModel.loadFromCache() } }
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

private struct GuestRow: View {
    let guest: Guest
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            StayTimeline(guest: guest, dateFormatter: dateFormatter)

            VStack(alignment: .leading, spacing: 3) {
                Text(guest.fullName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Passport/ID: \(guest.identificador)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let nationality = guest.nationality {
                    Text("Nationality: \(nationality)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct StayTimeline: View {
    let guest: Guest
    let dateFormatter: DateFormatter

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                Rectangle().fill(Color.secondary.opacity(0.3)).frame(width: 2, height: 15)
                Circle().fill(Color.orange).frame(width: 9, height: 9)
            }
            VStack(alignment: .leading, spacing: 9) {
                event(title: "Check-in", date: guest.checkIn)
                event(title: "Check-out", date: guest.checkOut)
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func event(title: LocalizedStringKey, date: Date?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let date {
                Text(dateFormatter.string(from: date))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
                Text(date, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
