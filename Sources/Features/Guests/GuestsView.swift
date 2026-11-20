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
                    Text("Sign in on Register to refresh portal data.").font(.caption).foregroundStyle(.secondary)
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
                if let message = viewModel.errorMessage, !viewModel.guests.isEmpty {
                    Text(message).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
                Picker("Segment", selection: $viewModel.segment) {
                    ForEach(GuestsViewModel.Segment.allCases) { segment in
                        Text(LocalizedStringKey(segment.rawValue)).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                content
            }
            .searchable(text: $viewModel.searchText, prompt: "Name or passport")
            .navigationTitle("Guests")
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
            List(guests) { guest in
                NavigationLink {
                    GuestDetailView(guest: guest, client: client, settings: settings)
                } label: {
                    GuestRow(guest: guest, dateFormatter: Self.displayDate)
                }
            }
            .refreshable { if appState.isSignedIn { await viewModel.reload() } }
        }
    }
}

private struct GuestRow: View {
    let guest: Guest
    let dateFormatter: DateFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(guest.fullName).font(.headline)
            Text("Passport: \(guest.identificador)").font(.subheadline)
            if let nationality = guest.nationality {
                Text("Nationality: \(nationality)").font(.subheadline).foregroundStyle(.secondary)
            }
            if let checkIn = guest.checkIn {
                Text("Check-in: \(dateFormatter.string(from: checkIn))").font(.caption)
            }
            if let checkOut = guest.checkOut {
                Text("Check-out: \(dateFormatter.string(from: checkOut))").font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}
