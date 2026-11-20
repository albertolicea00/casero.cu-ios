import CryptoKit
import Foundation

/// Disk cache for guest photos (`ObtenerFotoDiie` / `ObtenerFotoSUINPorCi`).
///
/// Cached by default; `AppSettings.saveImages == false` disables writes (and the
/// existing cache should be cleared alongside the guest cache when the user
/// flips that toggle off, via `clear()`).
actor PhotoCache {

    private(set) var generation = UUID()

    static let shared = PhotoCache()

    private let directory: URL

    init(directory: URL? = nil, fileManager: FileManager = .default) {
        let base = directory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = base.appendingPathComponent("guest-photos", isDirectory: true)
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func data(for url: URL, ttl: TimeInterval? = nil) -> Data? {
        let file = fileURL(for: url)
        if let ttl {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                let date = values.contentModificationDate, Date().timeIntervalSince(date) <= ttl
            else {
                try? FileManager.default.removeItem(at: file)
                return nil
            }
        }
        return try? Data(contentsOf: file)
    }

    func store(_ data: Data, for url: URL, generation expected: UUID? = nil) {
        guard expected == nil || expected == generation else { return }
        try? data.write(to: fileURL(for: url), options: [.atomic, .completeFileProtection])
    }

    func clear() {
        generation = UUID()
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}
