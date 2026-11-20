import Foundation
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var exportFrom = PortalDates.calendar.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var exportTo = Date()
    @Published var exportFormat: ExportService.Format = .csv
    @Published var includePhotosInPDF = false
    @Published private(set) var isExporting = false
    @Published var exportedFile: ExportedFile?
    @Published private(set) var errorMessage: String?
    @Published private(set) var noticeMessage: String?
    @Published private(set) var cacheSummary = String(localized: "No cached data.")

    struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    private var lastExportURL: URL?
    private let settings: AppSettings
    private let photoService: GuestPhotoService

    init(client: CaseroClient, settings: AppSettings) {
        self.settings = settings
        photoService = GuestPhotoService(client: client, settings: settings)
    }

    func removeExport() {
        if let url = lastExportURL { try? FileManager.default.removeItem(at: url) }
        exportedFile = nil
        lastExportURL = nil
    }

    func refreshCacheSummary() async {
        guard let snapshot = await GuestCache.shared.load() else {
            cacheSummary = String(localized: "No cached data.")
            return
        }
        let formatter = RelativeDateTimeFormatter()
        let age = formatter.localizedString(for: snapshot.fetchedAt, relativeTo: Date())
        cacheSummary = String(localized: "\(snapshot.guests.count) guests cached, last updated \(age).")
    }

    func clearCache() async {
        await GuestCache.shared.clear()
        await PhotoCache.shared.clear()
        await refreshCacheSummary()
    }

    func export() async {
        guard PortalDates.calendar.startOfDay(for: exportTo) >= PortalDates.calendar.startOfDay(for: exportFrom) else {
            errorMessage = String(localized: "Check-out range end must be after its start.")
            return
        }
        isExporting = true
        errorMessage = nil
        noticeMessage = nil
        defer { isExporting = false }

        guard let snapshot = await GuestCache.shared.load() else {
            errorMessage = String(localized: "Nothing cached yet — reload the Guests tab first.")
            return
        }
        if await GuestCache.shared.isStale(snapshot, ttl: settings.cacheTTL.interval) {
            await clearCache()
            errorMessage = String(localized: "Cached data has expired. Reload Guests before exporting.")
            return
        }
        let calendar = PortalDates.calendar
        let start = calendar.startOfDay(for: exportFrom)
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: exportTo))!
        if let cachedFrom = snapshot.rangeStart, let cachedTo = snapshot.rangeEnd,
            start < calendar.startOfDay(for: cachedFrom)
                || calendar.startOfDay(for: exportTo) > calendar.startOfDay(for: cachedTo)
        {
            errorMessage = String(
                localized:
                    "The selected dates are outside the cached range. Load that range in Guests before exporting.")
            return
        }
        let range = snapshot.guests.filter { guest in
            guard let checkIn = guest.checkIn else { return false }
            return checkIn >= start && checkIn < end
        }

        do {
            let data: Data
            let filename: String
            switch exportFormat {
            case .csv:
                data = ExportService.csv(for: range, from: exportFrom, to: exportTo)
                filename = "guests-\(UUID().uuidString).csv"
            case .pdf:
                let photos = includePhotosInPDF ? await fetchPhotos(for: range) : [:]
                data = ExportService.pdf(for: range, from: exportFrom, to: exportTo, photos: photos)
                filename = "guests-\(UUID().uuidString).pdf"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            removeExport()
            lastExportURL = url
            exportedFile = ExportedFile(url: url)
        } catch {
            errorMessage = String(localized: "Could not build export: \(error.localizedDescription)")
        }
    }

    /// Best-effort: skips any guest whose photo fails to download rather than
    /// failing the whole export.
    private func fetchPhotos(for guests: [Guest]) async -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        for guest in guests {
            guard let image = try? await photoService.image(for: guest) else { continue }
            result[guest.identificador] = image
        }
        if result.count < guests.count {
            noticeMessage = String(
                localized: "Some photos could not be loaded. The export includes the remaining data.")
        }
        return result
    }
}
