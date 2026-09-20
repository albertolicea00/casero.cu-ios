import Foundation

/// On-disk cache of the last successful guest fetch, so the "Guests" tab can
/// show something without a live connection. Not a general-purpose database —
/// one JSON snapshot, replaced wholesale on every successful reload.
actor GuestCache {

    struct Snapshot: Codable {
        let fetchedAt: Date
        let guests: [Guest]
    }

    static let shared = GuestCache()

    private let fileURL: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        fileURL = base.appendingPathComponent("guests-cache.json")
    }

    func save(_ guests: [Guest]) {
        let snapshot = Snapshot(fetchedAt: Date(), guests: guests)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// Whether a stored snapshot is still within `ttl` (`nil` TTL never expires).
    func isStale(_ snapshot: Snapshot, ttl: TimeInterval?) -> Bool {
        guard let ttl else { return false }
        return Date().timeIntervalSince(snapshot.fetchedAt) > ttl
    }
}
