import Foundation

@MainActor
final class GuestsViewModel: ObservableObject {

    enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case history = "History"
        case all = "All"
        var id: String { rawValue }
    }

    @Published var guests: [Guest] = []
    @Published var segment: Segment = .all
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isOffline = false
    @Published private(set) var lastFetched: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSessionExpired = false

    private let client: CaseroClient
    private let cache: GuestCache
    private let settings: AppSettings

    init(client: CaseroClient, cache: GuestCache = .shared, settings: AppSettings) {
        self.client = client
        self.cache = cache
        self.settings = settings
    }

    var filteredGuests: [Guest] {
        let now = Date()
        let bySegment = guests.filter { guest in
            switch segment {
            case .all: return true
            case .active: return (guest.checkOut ?? .distantFuture) >= now
            case .history: return (guest.checkOut ?? .distantFuture) < now
            }
        }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return bySegment }
        let needle = searchText.lowercased()
        return bySegment.filter {
            $0.fullName.lowercased().contains(needle) || $0.identificador.lowercased().contains(needle)
        }
    }

    /// Loads from cache first for instant offline display, then optionally refreshes.
    func loadFromCache() async {
        guard let snapshot = await cache.load() else { return }
        guests = snapshot.guests
        lastFetched = snapshot.fetchedAt
        isOffline = await cache.isStale(snapshot, ttl: settings.cacheTTL.interval)
    }

    /// Fetches fresh data from the portal. Called on pull-to-refresh / the reload button.
    func reload() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let now = Date()
            let calendar = Calendar.current
            let from = calendar.date(byAdding: .month, value: -3, to: now) ?? now
            let to = calendar.date(byAdding: .month, value: 1, to: now) ?? now
            let fresh = try await client.listGuests(from: from, to: to, pageSize: 200, page: 1)
            guests = fresh
            lastFetched = Date()
            isOffline = false
            await cache.save(fresh)
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch {
            // Keep whatever cached data is already on screen; surface the error alongside it.
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
            isOffline = !guests.isEmpty
        }
    }

    func acknowledgeSessionExpired() {
        isSessionExpired = false
    }

    func signOut() async {
        await client.signOut()
    }
}
