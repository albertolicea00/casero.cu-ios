import CryptoKit
import Foundation

/// Disk cache for guest photos (`ObtenerFotoDiie` / `ObtenerFotoSUINPorCi`).
///
/// Cached by default; `AppSettings.saveImages == false` disables writes (and the
/// existing cache should be cleared alongside the guest cache when the user
/// flips that toggle off, via `clear()`).
actor PhotoCache {

    static let shared = PhotoCache()

    private let directory: URL

    init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("guest-photos", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func data(for url: URL) -> Data? {
        try? Data(contentsOf: fileURL(for: url))
    }

    func store(_ data: Data, for url: URL) {
        try? data.write(to: fileURL(for: url), options: .atomic)
    }

    func clear() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for url: URL) -> URL {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return directory.appendingPathComponent(name)
    }
}
