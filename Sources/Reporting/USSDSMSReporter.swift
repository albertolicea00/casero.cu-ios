import Foundation

/// Offline reporting channel on iOS.
///
/// iOS is far more restricted than Android here:
/// - **USSD:** dialing works only for plain `tel://` numbers. Codes containing
///   `*` or `#` are blocked by iOS and cannot be auto-run — the user must type
///   them into the dialer manually.
/// - **SMS:** apps cannot send SMS silently. The best we can do is present a
///   pre-filled compose sheet (`MessageComposeView`) that the user taps to send.
///
/// TODO: the exact USSD/SMS report format is not specified yet. `smsDestination`
/// and `reportBody` are placeholders — fill them from the official reporting spec
/// before shipping. Do not guess the code in production.
enum USSDSMSReporter {

    /// Placeholder short number for SMS reports.
    static let smsDestination = "TODO"

    /// Placeholder report body. Replace with the real format.
    static func reportBody(passport: String) -> String {
        "TODO \(passport)"
    }

    /// A `tel://` URL for a dialable code, or `nil` if iOS would block it (USSD with `*`/`#`).
    static func dialURL(for code: String) -> URL? {
        let dialable = CharacterSet(charactersIn: "0123456789+")
        guard code.unicodeScalars.allSatisfy(dialable.contains) else { return nil }
        return URL(string: "tel://\(code)")
    }
}
