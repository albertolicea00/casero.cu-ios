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

    /// What a registration PDF records. Every variant is a trace for the host;
    /// only the stay IDs returned by the portal prove a registration.
    enum RegistrationRecord {
        /// Saved from the review sheet, before sending.
        case prepared([GuestRegistration])
        /// The portal's answer, one row per person (status and stay ID).
        case submitted([Guest])
        /// Sending failed or its answer was lost; the people may not be registered.
        case failed([GuestRegistration], reason: String, uncertain: Bool)
    }

    private struct RegistrationRow {
        let name: String
        let identificador: String
        let nationality: String?
        let birthDate: Date?
        let checkIn: Date?
        let checkOut: Date?
        let status: String?
        let stayId: String?
    }

    static func registrationPDF(
        _ record: RegistrationRecord, photos: [String: UIImage] = [:], generatedAt: Date = .now
    ) -> Data {
        let timestampFormatter = DateFormatter()
        timestampFormatter.locale = Locale(identifier: "en_US_POSIX")
        timestampFormatter.dateFormat = "dd/MM/yyyy HH:mm"
        timestampFormatter.timeZone = TimeZone(identifier: "America/Havana")
        let when = timestampFormatter.string(from: generatedAt)
        let inPerson = String(
            localized:
                "If the registration cannot be completed, report these people by SMS from the SMS tab, or take this document to the nearest immigration office and report them there."
        )

        func row(_ entry: GuestRegistration, status: String?) -> RegistrationRow {
            RegistrationRow(
                name: "\(entry.firstName) \(entry.middleName) \(entry.lastName1) \(entry.lastName2)",
                identificador: entry.identificador, nationality: entry.nationalityName, birthDate: entry.birthDate,
                checkIn: entry.checkIn, checkOut: entry.checkOut, status: status, stayId: nil)
        }

        let title: String
        let notes: [String]
        let rows: [RegistrationRow]
        switch record {
        case .prepared(let entries):
            title = String(localized: "Guest registration — prepared")
            notes = [
                String(
                    localized:
                        "Prepared in CASEROcu on \(when) (Cuba time), before sending. This is not proof of registration: only the stay IDs returned by the official portal confirm it."
                )
            ]
            rows = entries.map { row($0, status: nil) }
        case .submitted(let guests):
            let rejected = guests.filter { $0.response != "OK" }
            title =
                rejected.isEmpty
                ? String(localized: "Guest registration — registered")
                : String(localized: "Guest registration — partly registered")
            var text = [
                String(
                    localized:
                        "Sent from CASEROcu to the official portal on \(when) (Cuba time). People marked Registered were accepted with the stay ID shown."
                )
            ]
            if !rejected.isEmpty {
                text.append(String(localized: "People marked Not registered were not accepted by the portal."))
                text.append(inPerson)
            }
            notes = text
            rows = guests.map { guest in
                RegistrationRow(
                    name: guest.fullName.replacingOccurrences(of: "*", with: " "),
                    identificador: guest.identificador, nationality: guest.nationality, birthDate: guest.birthDate,
                    checkIn: guest.checkIn, checkOut: guest.checkOut,
                    status: guest.response == "OK"
                        ? String(localized: "Registered")
                        : String(localized: "Not registered: \(guest.response ?? String(localized: "Unconfirmed"))"),
                    stayId: guest.stayId.isEmpty ? nil : guest.stayId)
            }
        case .failed(let entries, let reason, let uncertain):
            title = String(localized: "Guest registration — not completed")
            var text = [
                String(localized: "Attempted from CASEROcu on \(when) (Cuba time). Error: \(reason)")
            ]
            if uncertain {
                text.append(
                    String(
                        localized:
                            "The answer was lost after sending: these people may already be registered. Check the official portal or the Guests list before reporting them again, to avoid duplicates."
                    ))
            }
            text.append(inPerson)
            notes = text
            rows = entries.map {
                row($0, status: uncertain ? String(localized: "Not confirmed") : String(localized: "Not registered"))
            }
        }

        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let margin: CGFloat = 36
        let width = page.width - 2 * margin
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let rowAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
        let nameAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12)]
        let titleAttributes: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 16)]
        let noteAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10), .foregroundColor: UIColor.darkGray,
        ]
        let noteText = notes.joined(separator: "\n\n")

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
                    in: CGRect(x: margin, y: margin, width: width, height: titleHeight), withAttributes: titleAttributes)
                y = margin + titleHeight + 6
                let noteHeight = height(noteText, width: width, attributes: noteAttributes)
                (noteText as NSString).draw(
                    in: CGRect(x: margin, y: y, width: width, height: noteHeight), withAttributes: noteAttributes)
                y += noteHeight + 18
            }
            beginPage()
            for item in rows {
                let photo = photos[item.identificador]
                let photoWidth: CGFloat = photo == nil ? 0 : 56
                let textWidth = width - photoWidth
                let name = item.name.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                var lines: [String] = []
                if let status = item.status { lines.append(status) }
                if let stayId = item.stayId { lines.append(String(localized: "Stay ID: \(stayId)")) }
                lines.append(String(localized: "Passport/ID: \(item.identificador) — \(item.nationality ?? "")"))
                if let birthDate = item.birthDate {
                    lines.append(String(localized: "Born: \(dateFormatter.string(from: birthDate))"))
                }
                if let checkIn = item.checkIn, let checkOut = item.checkOut {
                    let nights = max(
                        0,
                        PortalDates.calendar.dateComponents(
                            [.day], from: PortalDates.calendar.startOfDay(for: checkIn),
                            to: PortalDates.calendar.startOfDay(for: checkOut)
                        ).day ?? 0)
                    lines.append(
                        String(
                            localized:
                                "Check-in: \(dateFormatter.string(from: checkIn))  Check-out: \(dateFormatter.string(from: checkOut))  (\(nights) nights)"
                        ))
                }
                let details = lines.joined(separator: "\n")
                let nameHeight = height(name, width: textWidth, attributes: nameAttributes)
                let detailsHeight = height(details, width: textWidth, attributes: rowAttributes)
                let rowHeight = max(photo == nil ? 0 : 48, nameHeight + 2 + detailsHeight)
                if y + rowHeight > page.height - margin { beginPage() }
                if let photo {
                    let ratio = min(48 / photo.size.width, 48 / photo.size.height)
                    photo.draw(
                        in: CGRect(x: margin, y: y, width: photo.size.width * ratio, height: photo.size.height * ratio))
                }
                (name as NSString).draw(
                    in: CGRect(x: margin + photoWidth, y: y, width: textWidth, height: nameHeight),
                    withAttributes: nameAttributes)
                (details as NSString).draw(
                    in: CGRect(x: margin + photoWidth, y: y + nameHeight + 2, width: textWidth, height: detailsHeight),
                    withAttributes: rowAttributes)
                y += rowHeight + 14
            }
        }
    }

    /// Writes a PDF to the temp folder with file protection, for the share sheet.
    static func writeRegistrationPDF(_ data: Data, generatedAt: Date = .now) -> URL? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        formatter.timeZone = TimeZone(identifier: "America/Havana")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("registration-\(formatter.string(from: generatedAt)).pdf")
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            return url
        } catch {
            return nil
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
