import Foundation
import UIKit

/// Exports are generated locally from the complete cached date range.
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
        formatter.timeZone = TimeZone(identifier: "America/Havana")
        return formatter
    }()

    static func csv(for guests: [Guest], from: Date, to: Date) -> Data {
        var lines = [
            [
                String(localized: "Name"), String(localized: "Passport/ID"), String(localized: "Nationality"),
                String(localized: "Check-in"), String(localized: "Check-out"),
            ].map(csvEscape).joined(separator: ",")
        ]
        for guest in guests {
            lines.append(
                [
                    guest.fullName, guest.identificador, guest.nationality ?? "",
                    guest.checkIn.map(dateFormatter.string) ?? "",
                    guest.checkOut.map(dateFormatter.string) ?? "",
                ].map(csvEscape).joined(separator: ","))
        }
        // A BOM lets Excel detect accented UTF-8 names correctly.
        return Data(("\u{FEFF}" + lines.joined(separator: "\r\n")).utf8)
    }

    static func pdf(for guests: [Guest], from: Date, to: Date, photos: [String: UIImage] = [:]) -> Data {
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let width = page.width - 2 * margin
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let rowAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
        let title = String(
            localized: "Guest report: \(dateFormatter.string(from: from)) – \(dateFormatter.string(from: to))")

        func height(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
            ceil(
                (text as NSString).boundingRect(
                    with: CGSize(width: width, height: .greatestFiniteMagnitude),
                    options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil
                ).height)
        }

        return renderer.pdfData { context in
            var y: CGFloat = margin
            func beginPage() {
                context.beginPage()
                let titleHeight = height(title, width: width, attributes: titleAttributes)
                (title as NSString).draw(
                    in: CGRect(x: margin, y: margin, width: width, height: titleHeight), withAttributes: titleAttributes
                )
                y = margin + titleHeight + 16
            }
            beginPage()
            for guest in guests {
                let photo = photos[guest.identificador]
                let photoWidth: CGFloat = photo == nil ? 0 : 48
                let textWidth = width - photoWidth
                let text = [
                    guest.fullName,
                    String(localized: "Passport/ID: \(guest.identificador) — \(guest.nationality ?? "")"),
                    String(
                        localized:
                            "Check-in: \(guest.checkIn.map(dateFormatter.string) ?? "—")  Check-out: \(guest.checkOut.map(dateFormatter.string) ?? "—")"
                    ),
                ].joined(separator: "\n")
                let textHeight = height(text, width: textWidth, attributes: rowAttributes)
                let rowHeight = max(photo == nil ? 0 : 40, textHeight)
                if y + rowHeight > page.height - margin { beginPage() }
                if let photo {
                    let ratio = min(40 / photo.size.width, 40 / photo.size.height)
                    photo.draw(
                        in: CGRect(x: margin, y: y, width: photo.size.width * ratio, height: photo.size.height * ratio))
                }
                (text as NSString).draw(
                    in: CGRect(x: margin + photoWidth, y: y, width: textWidth, height: textHeight),
                    withAttributes: rowAttributes)
                y += rowHeight + 12
            }
        }
    }

    private static func csvEscape(_ raw: String) -> String {
        // Quoting alone does not prevent Excel from interpreting formulas.
        let first = raw.trimmingCharacters(in: .whitespacesAndNewlines).first
        let field = first.map { "=+-@".contains($0) } == true ? "'" + raw : raw
        guard field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") else {
            return field
        }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }
}
