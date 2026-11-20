import Foundation
import UIKit

@MainActor
final class GuestPhotoService {
    private let client: CaseroClient
    private let settings: AppSettings
    private let cache: PhotoCache

    init(client: CaseroClient, settings: AppSettings, cache: PhotoCache = .shared) {
        self.client = client
        self.settings = settings
        self.cache = cache
    }

    func image(for guest: Guest, isCompanion: Bool = false, forceRefresh: Bool = false) async throws -> UIImage {
        guard let url = cacheURL(for: guest, isCompanion: isCompanion) else { throw PortalError.invalidResponse }
        if !forceRefresh, settings.saveImages,
            let data = await cache.data(for: url, ttl: settings.cacheTTL.interval),
            let image = UIImage(data: data)
        {
            return image
        }
        let generation = await cache.generation
        let data: Data
        if isCompanion || guest.nationality?.uppercased() == "CUBA" {
            data = try await client.fetchCompanionPhoto(carne: guest.identificador)
        } else {
            data = try await client.fetchForeignGuestPhoto(
                passport: guest.identificador, name: guest.fullName,
                nationalityCode: guest.nationalityCode ?? "", sex: guest.sex ?? "")
        }
        try Task.checkCancellation()
        guard let image = UIImage(data: data) else { throw PortalError.invalidResponse }
        if settings.saveImages { await cache.store(data, for: url, generation: generation) }
        return image
    }

    func cachedImage(for guest: Guest, isCompanion: Bool = false) async -> UIImage? {
        guard settings.saveImages,
            let url = cacheURL(for: guest, isCompanion: isCompanion),
            let data = await cache.data(for: url, ttl: settings.cacheTTL.interval)
        else { return nil }
        return UIImage(data: data)
    }

    private func cacheURL(for guest: Guest, isCompanion: Bool) -> URL? {
        var key = URLComponents()
        key.scheme = "casero-photo"
        key.host = "guest"
        key.queryItems = [
            URLQueryItem(name: "id", value: guest.identificador),
            URLQueryItem(name: "nationality", value: guest.nationalityCode),
            URLQueryItem(name: "kind", value: isCompanion ? "companion" : "guest"),
        ]
        return key.url
    }
}
