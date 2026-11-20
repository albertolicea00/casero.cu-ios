import PDFKit
import XCTest

@testable import CaseroCu

@MainActor
final class ExportAndCacheTests: XCTestCase {
    func testCSVPreservesUTF8AndEscapesFormulasQuotesAndNewlines() throws {
        let object = ["Biografico": "=SUM(1,2)\n\"José\"", "Identificador": "TEST", "EstanciaId": "1"]
        let guest = try JSONDecoder().decode(Guest.self, from: JSONSerialization.data(withJSONObject: object))
        let data = ExportService.csv(for: [guest], from: Date(), to: Date())
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.hasPrefix("\u{FEFF}"))
        XCTAssertTrue(text.contains("\"'=SUM(1,2)\n\"\"José\"\"\""))
    }

    func testPDFSpansPagesAndKeepsLastGuest() throws {
        let guests = try (0..<40).map { try fixtureGuest(id: "TEST-\($0)") }
        let data = ExportService.pdf(for: guests, from: Date(), to: Date())
        let document = try XCTUnwrap(PDFDocument(data: data))
        XCTAssertGreaterThan(document.pageCount, 1)
        XCTAssertTrue(document.string?.contains("TEST-39") == true)
    }

    func testPhotoRetentionRemovesExpiredData() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = PhotoCache(directory: directory)
        let url = URL(string: "https://example.invalid/test-photo")!
        await cache.store(Data([1, 2, 3]), for: url)
        let saved = await cache.data(for: url)
        XCTAssertEqual(saved, Data([1, 2, 3]))
        let expired = await cache.data(for: url, ttl: -1)
        XCTAssertNil(expired)
        let removed = await cache.data(for: url)
        XCTAssertNil(removed)
    }

    func testGuestCacheRoundTripAndClearOnDisk() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = GuestCache(directory: directory)
        let guest = try fixtureGuest()
        await cache.save([guest], from: guest.checkIn, to: guest.checkOut)
        let restored = await cache.load()
        XCTAssertEqual(restored?.guests.first?.birthDate, guest.birthDate)
        await cache.clear()
        let empty = await cache.load()
        XCTAssertNil(empty)
    }

    func testSingleDayExportIncludesMidnightAndRemovesTemporaryFile() async throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "CaseroCuTests.Export"))
        let settings = AppSettings(defaults: defaults)
        settings.cacheTTL = .forever
        let model = SettingsViewModel(client: CaseroClient(), settings: settings)
        let guest = try fixtureGuest()
        let day = try XCTUnwrap(guest.checkIn)
        let start = PortalDates.calendar.startOfDay(for: day)
        model.exportFrom = start.addingTimeInterval(12 * 3600)
        model.exportTo = start.addingTimeInterval(1 * 3600)
        await GuestCache.shared.save([guest], from: start, to: start)
        await model.export()
        let url = try XCTUnwrap(model.exportedFile?.url)
        let text = try String(contentsOf: url, encoding: .utf8)
        XCTAssertTrue(text.contains("TEST-A"))
        // SwiftUI clears the sheet binding before calling onDismiss.
        model.exportedFile = nil
        model.removeExport()
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
        await GuestCache.shared.clear()
        defaults.removePersistentDomain(forName: "CaseroCuTests.Export")
    }
}

extension ExportAndCacheTests {
    func testCacheClearRejectsAnOlderInFlightFetch() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = GuestCache(directory: directory)
        let generation = await cache.generation
        await cache.clear()
        await cache.save([try fixtureGuest()], generation: generation)
        let snapshot = await cache.load()
        XCTAssertNil(snapshot)
    }
}
