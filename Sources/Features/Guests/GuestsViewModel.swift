import Foundation

@MainActor
final class GuestsViewModel: ObservableObject {

    enum Segment: String, CaseIterable, Identifiable {
        case active = "Active"
        case history = "History"
        var id: String { rawValue }
    }

    enum SortOrder: String, CaseIterable, Identifiable {
        case newestFirst = "Newest first"
        case oldestFirst = "Oldest first"
        var id: String { rawValue }
    }

    @Published var from: Date
    @Published var to: Date
    @Published var guests: [Guest] = []
    @Published var segment: Segment = .active
    @Published var sortOrder: SortOrder = .newestFirst
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
        let today = Date()
        from = PortalDates.calendar.date(byAdding: .day, value: -settings.defaultGuestRangeDays, to: today) ?? today
        to = today
    }

    func applyDefaultRange() {
        let today = Date()
        from = PortalDates.calendar.date(byAdding: .day, value: -settings.defaultGuestRangeDays, to: today) ?? today
        to = today
    }

    var filteredGuests: [Guest] {
        let now = Date()
        let bySegment = guests.filter { guest in
            switch segment {
            case .active:
                return (guest.checkIn ?? .distantPast) <= now
                    && (guest.checkOut ?? .distantFuture) >= PortalDates.calendar.startOfDay(for: now)
            case .history: return (guest.checkOut ?? .distantFuture) < PortalDates.calendar.startOfDay(for: now)
            }
        }
        let bySearch: [Guest]
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if needle.isEmpty {
            bySearch = bySegment
        } else {
            bySearch = bySegment.filter {
                $0.fullName.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                    || $0.identificador.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
        return bySearch.sorted {
            let left = $0.checkIn ?? .distantPast
            let right = $1.checkIn ?? .distantPast
            return sortOrder == .newestFirst ? left > right : left < right
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
