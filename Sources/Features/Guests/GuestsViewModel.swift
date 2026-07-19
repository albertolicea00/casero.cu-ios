import Foundation

@MainActor
final class GuestsViewModel: ObservableObject {

    enum ViewState {
        case loading
        case content([Guest])
        case error(String)
        case sessionExpired
    }

    @Published var state: ViewState = .loading

    private let client: CaseroClient

    init(client: CaseroClient) {
        self.client = client
    }

    var isSessionExpired: Bool {
        if case .sessionExpired = state { return true }
        return false
    }

    func load() async {
        state = .loading
        do {
            let now = Date()
            let calendar = Calendar.current
            let from = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            let to = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            let guests = try await client.listGuests(from: from, to: to)
            state = .content(guests)
        } catch PortalError.sessionExpired {
            state = .sessionExpired
        } catch {
            state = .error((error as? PortalError)?.errorDescription ?? error.localizedDescription)
        }
    }

    func signOut() async {
        await client.signOut()
    }
}
