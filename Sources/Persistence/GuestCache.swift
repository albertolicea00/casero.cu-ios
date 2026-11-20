import Foundation

/// On-disk cache of the last successful guest fetch, so the "Guests" tab can
/// show something without a live connection. Not a general-purpose database —
/// one JSON snapshot, replaced wholesale on every successful reload.
actor GuestCache {

    struct Snapshot: Codable {
        let fetchedAt: Date
        let guests: [Guest]
        var rangeStart: Date? = nil
        var rangeEnd: Date? = nil
    }

    struct CompanionSnapshot: Codable {
        let fetchedAt: Date
        let companions: [Guest]
    }

    private(set) var generation = UUID()

    static let shared = GuestCache()

    private let fileURL: URL
    private let companionsFileURL: URL

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        let base = directory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        try? fileManager.createDirectory(at: base, withIntermediateDirectories: true)
        fileURL = base.appendingPathComponent("guests-cache.json")
        companionsFileURL = base.appendingPathComponent("companions-cache.json")
    }

    func save(_ guests: [Guest], from: Date? = nil, to: Date? = nil, generation expected: UUID? = nil) {
        guard expected == nil || expected == generation else { return }
        let snapshot = Snapshot(fetchedAt: Date(), guests: guests, rangeStart: from, rangeEnd: to)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtection])
    }

    func load() -> Snapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    func saveCompanions(_ companions: [Guest], for stayId: String) {
        guard !stayId.isEmpty else { return }
        var snapshots = loadCompanionSnapshots()
        snapshots[stayId] = CompanionSnapshot(fetchedAt: Date(), companions: companions)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: companionsFileURL, options: [.atomic, .completeFileProtection])
    }

    func loadCompanions(for stayId: String) -> CompanionSnapshot? {
        guard !stayId.isEmpty else { return nil }
        return loadCompanionSnapshots()[stayId]
    }

    func removeCompanions(for stayId: String) {
        var snapshots = loadCompanionSnapshots()
        snapshots.removeValue(forKey: stayId)
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        try? data.write(to: companionsFileURL, options: [.atomic, .completeFileProtection])
    }

    func clear() {
        generation = UUID()
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: companionsFileURL)
    }

    /// Whether a stored snapshot is still within `ttl` (`nil` TTL never expires).
    func isStale(_ snapshot: Snapshot, ttl: TimeInterval?) -> Bool {
        guard let ttl else { return false }
        return Date().timeIntervalSince(snapshot.fetchedAt) > ttl
    }

    func isStale(_ snapshot: CompanionSnapshot, ttl: TimeInterval?) -> Bool {
        guard let ttl else { return false }
        return Date().timeIntervalSince(snapshot.fetchedAt) > ttl
    }

    private func loadCompanionSnapshots() -> [String: CompanionSnapshot] {
        guard let data = try? Data(contentsOf: companionsFileURL) else { return [:] }
        return (try? JSONDecoder().decode([String: CompanionSnapshot].self, from: data)) ?? [:]
    }
}
