import SwiftUI

struct GuestsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: GuestsViewModel

    init(client: CaseroClient) {
        _viewModel = StateObject(wrappedValue: GuestsViewModel(client: client))
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
            content
                .navigationTitle("Registered guests")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign out") {
                            Task {
                                await viewModel.signOut()
                                appState.isSignedIn = false
                            }
                        }
                    }
                }
        }
        .task { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ProgressView()

        case .content(let guests):
            if guests.isEmpty {
                Text("No guests in this range.").foregroundStyle(.secondary)
            } else {
                List(guests) { guest in
                    GuestRow(guest: guest, dateFormatter: Self.displayDate)
                }
            }

        case .error(let message):
            VStack(spacing: 12) {
                Text(message).foregroundStyle(.red).multilineTextAlignment(.center)
                Button("Retry") { Task { await reload() } }
                    .buttonStyle(.bordered)
            }
            .padding()

        case .sessionExpired:
            ProgressView()
        }
    }

    private func reload() async {
        await viewModel.load()
        if viewModel.isSessionExpired {
            appState.isSignedIn = false
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
