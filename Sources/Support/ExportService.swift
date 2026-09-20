import Foundation
import PDFKit
import UIKit

/// Builds guest exports entirely on-device from already-cached data — the
/// portal has no export endpoint. "Excel" is delivered as CSV (Excel opens CSV
/// natively); generating a genuine `.xlsx` would need a zip/XML writer this app
/// doesn't have, and CSV covers the same need without one.
enum ExportService {

    enum Format: String, CaseIterable, Identifiable {
        case csv = "CSV / Excel"
        case pdf = "PDF"
        var id: String { rawValue }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yyyy"
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter
    }()

    static func csv(for guests: [Guest], from: Date, to: Date) -> Data {
        var lines = ["Name,Passport/ID,Nationality,Check-in,Check-out"]
        for guest in guests {
            let fields = [
                guest.fullName,
                guest.identificador,
                guest.nationality ?? "",
                guest.checkIn.map(dateFormatter.string) ?? "",
                guest.checkOut.map(dateFormatter.string) ?? "",
            ].map(csvEscape)
            lines.append(fields.joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    /// Renders a simple table PDF. `photos` are only fetched/embedded when the
    /// caller explicitly passes them (never on a plain data export).
    static func pdf(for guests: [Guest], from: Date, to: Date, photos: [String: UIImage] = [:]) -> Data {
        let pageWidth: CGFloat = 612 // US Letter
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 36
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))

        return renderer.pdfData { context in
            context.beginPage()
            var y: CGFloat = margin

            let title = "Guest report: \(dateFormatter.string(from: from)) – \(dateFormatter.string(from: to))"
            title.draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 16)])
            y += 28

            let rowFont = UIFont.systemFont(ofSize: 11)
            let photoSize: CGFloat = 40

            for guest in guests {
                if y > pageHeight - margin - photoSize {
                    context.beginPage()
                    y = margin
                }

                if let photo = photos[guest.identificador] {
                    photo.draw(in: CGRect(x: margin, y: y, width: photoSize, height: photoSize))
                }

                let textX = photos.isEmpty ? margin : margin + photoSize + 8
                let lines = [
                    guest.fullName,
                    "Passport/ID: \(guest.identificador) — \(guest.nationality ?? "")",
                    "Check-in: \(guest.checkIn.map(dateFormatter.string) ?? "—")  Check-out: \(guest.checkOut.map(dateFormatter.string) ?? "—")",
                ]
                for (index, line) in lines.enumerated() {
                    line.draw(at: CGPoint(x: textX, y: y + CGFloat(index) * 14), withAttributes: [.font: rowFont])
                }
                y += max(photoSize, CGFloat(lines.count) * 14) + 10
            }
        }
    }

    private static func csvEscape(_ field: String) -> String {
        guard field.contains(",") || field.contains("\"") || field.contains("\n") else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
