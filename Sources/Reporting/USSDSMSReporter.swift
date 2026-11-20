import Foundation

/// Published SMS procedure supplied with the project's reference pages.
/// Each guest/companion report has a separate confirmation exchange.
enum USSDSMSReporter {
    static let isAvailable = true
    static let smsDestination = "7344"
    static let associationPhone = "18808"
    static let instructionsURL = URL(
        string:
            "https://cubatramite.com/reporte-a-inmigracion-del-registro-de-turistas-extranjeros-hospedados-en-viviendas-de-alquiler/"
    )!

    enum ValidationError: LocalizedError {
        case passport, companionIdentity, days, confirmationCode, messageTooLong

        var errorDescription: String? {
            switch self {
            case .passport:
                return String(localized: "Enter a passport using only letters and digits.")
            case .companionIdentity:
                return String(localized: "Enter the companion's 11-digit identity number.")
            case .days:
                return String(localized: "Enter a positive whole number of stay days.")
            case .confirmationCode:
                return String(localized: "Enter only the received confirmation code, without HC or spaces.")
            case .messageTooLong:
                return String(localized: "The report is too long for one SMS. Check the entered data.")
            }
        }
    }

    static func reportBody(passport: String, days: String, companionIdentity: String? = nil) throws -> String {
        guard let passport = normalizedIdentifier(passport) else { throw ValidationError.passport }
        let dayText = days.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !dayText.isEmpty, dayText.allSatisfy({ $0.isASCII && $0.isNumber }),
            let count = Int(dayText), count > 0
        else { throw ValidationError.days }
        var fields = ["HC" + passport]
        if let companionIdentity {
            let identity = companionIdentity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard identity.count == 11, identity.allSatisfy({ $0.isASCII && $0.isNumber }) else {
                throw ValidationError.companionIdentity
            }
            fields.append(identity)
        }
        fields.append(String(count))
        return try checkedLength(fields.joined(separator: " "))
    }

    static func confirmationBody(code: String) throws -> String {
        guard let code = normalizedIdentifier(code), !code.hasPrefix("HC") else {
            throw ValidationError.confirmationCode
        }
        return try checkedLength("HC" + code)
    }

    private static func normalizedIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        guard !trimmed.isEmpty, trimmed.unicodeScalars.allSatisfy(allowed.contains) else { return nil }
        return trimmed.uppercased()
    }

    private static func checkedLength(_ body: String) throws -> String {
        guard body.count <= 160 else { throw ValidationError.messageTooLong }
        return body
    }

    /// Plain telephone numbers can be handed to the system dialer.
    static func dialURL(for code: String) -> URL? {
        let dialable = CharacterSet(charactersIn: "0123456789+")
        guard !code.isEmpty, code.unicodeScalars.allSatisfy(dialable.contains) else { return nil }
        return URL(string: "tel://\(code)")
    }
}
