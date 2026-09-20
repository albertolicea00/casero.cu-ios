import SwiftUI

struct GuestsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: GuestsViewModel

    init(client: CaseroClient, settings: AppSettings) {
        _viewModel = StateObject(wrappedValue: GuestsViewModel(client: client, settings: settings))
    }

    private static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yy"
        formatter.timeZone = TimeZone(identifier: "UTC")
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

                Picker("Segment", selection: $viewModel.segment) {
                    ForEach(GuestsViewModel.Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
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
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .disabled(viewModel.isLoading)
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
            await viewModel.reload()
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
            return "Showing cached data from \(Self.displayDate.string(from: lastFetched))."
        }
        return "Showing cached data."
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
                GuestRow(guest: guest, dateFormatter: Self.displayDate)
            }
            .refreshable { await viewModel.reload() }
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
