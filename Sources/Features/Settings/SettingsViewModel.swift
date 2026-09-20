import Foundation
import UIKit

@MainActor
final class SettingsViewModel: ObservableObject {

    @Published var exportFrom = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @Published var exportTo = Date()
    @Published var exportFormat: ExportService.Format = .csv
    @Published var includePhotosInPDF = false
    @Published private(set) var isExporting = false
    @Published var exportedFile: ExportedFile?
    @Published private(set) var errorMessage: String?
    @Published private(set) var cacheSummary = "No cached data."

    struct ExportedFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    private let client: CaseroClient

    init(client: CaseroClient) {
        self.client = client
    }

    func refreshCacheSummary() async {
        guard let snapshot = await GuestCache.shared.load() else {
            cacheSummary = "No cached data."
            return
        }
        let formatter = RelativeDateTimeFormatter()
        let age = formatter.localizedString(for: snapshot.fetchedAt, relativeTo: Date())
        cacheSummary = "\(snapshot.guests.count) guests cached, last updated \(age)."
    }

    func clearCache() async {
        await GuestCache.shared.clear()
        await PhotoCache.shared.clear()
        await refreshCacheSummary()
    }

    func export() async {
        guard exportTo >= exportFrom else {
            errorMessage = "Check-out range end must be after its start."
            return
        }
        isExporting = true
        errorMessage = nil
        defer { isExporting = false }

        guard let snapshot = await GuestCache.shared.load() else {
            errorMessage = "Nothing cached yet — reload the Guests tab first."
            return
        }
        let range = snapshot.guests.filter { guest in
            guard let checkIn = guest.checkIn else { return false }
            return checkIn >= exportFrom && checkIn <= exportTo
        }

        do {
            let data: Data
            let filename: String
            switch exportFormat {
            case .csv:
                data = ExportService.csv(for: range, from: exportFrom, to: exportTo)
                filename = "guests.csv"
            case .pdf:
                let photos = includePhotosInPDF ? await fetchPhotos(for: range) : [:]
                data = ExportService.pdf(for: range, from: exportFrom, to: exportTo, photos: photos)
                filename = "guests.pdf"
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            exportedFile = ExportedFile(url: url)
        } catch {
            errorMessage = "Could not build export: \(error.localizedDescription)"
        }
    }

    /// Best-effort: skips any guest whose photo fails to download rather than
    /// failing the whole export.
    private func fetchPhotos(for guests: [Guest]) async -> [String: UIImage] {
        var result: [String: UIImage] = [:]
        for guest in guests {
            guard let data = try? await client.fetchForeignGuestPhoto(
                passport: guest.identificador,
                name: guest.fullName,
                nationalityCode: guest.nationalityCode ?? "",
                sex: guest.sex ?? "",
            ), let image = UIImage(data: data) else { continue }
            result[guest.identificador] = image
        }
        return result
    }
}
