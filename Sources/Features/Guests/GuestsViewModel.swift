import Foundation

@MainActor
final class GuestsViewModel: ObservableObject {

    enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case history = "History"
        case all = "All"
        var id: String { rawValue }
    }

    @Published var from = PortalDates.calendar.date(byAdding: .month, value: -3, to: Date()) ?? Date()
    @Published var to = Date()
    @Published var guests: [Guest] = []
    @Published var segment: Segment = .all
    @Published var searchText = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isOffline = false
    @Published private(set) var lastFetched: Date?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isSessionExpired = false

    private let client: any PortalServing
    private let cache: GuestCache
    private let settings: AppSettings

    init(client: any PortalServing, cache: GuestCache = .shared, settings: AppSettings) {
        self.client = client
        self.cache = cache
        self.settings = settings
    }

    var filteredGuests: [Guest] {
        let now = Date()
        let bySegment = guests.filter { guest in
            switch segment {
            case .all: return true
            case .active:
                return (guest.checkIn ?? .distantPast) <= now
                    && (guest.checkOut ?? .distantFuture) >= PortalDates.calendar.startOfDay(for: now)
            case .history: return (guest.checkOut ?? .distantFuture) < PortalDates.calendar.startOfDay(for: now)
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
        if await cache.isStale(snapshot, ttl: settings.cacheTTL.interval) {
            await cache.clear()
            guests = []
            lastFetched = nil
            await PhotoCache.shared.clear()
            return
        }
        if let start = snapshot.rangeStart { from = start }
        if let end = snapshot.rangeEnd { to = end }
        guests = snapshot.guests
        lastFetched = snapshot.fetchedAt
        isOffline = true
    }

    /// Fetches fresh data from the portal. Called on pull-to-refresh / the reload button.
    func reload() async {
        guard !isLoading else { return }
        guard PortalDates.calendar.startOfDay(for: from) <= PortalDates.calendar.startOfDay(for: to) else {
            errorMessage = String(localized: "The end date must be on or after the start date.")
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        let generation = await cache.generation
        do {
            let start = PortalDates.calendar.startOfDay(for: from)
            let end = PortalDates.calendar.startOfDay(for: to)
            let fresh = try await client.listGuests(from: start, to: end, pageSize: 100, page: 1)
            guests = fresh
            lastFetched = Date()
            isOffline = false
            let currentGeneration = await cache.generation
            guard generation == currentGeneration else {
                guests = []
                return
            }
            await cache.save(fresh, from: start, to: end, generation: generation)
        } catch is CancellationError {
            return
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
