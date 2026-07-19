import Foundation

/// Parses ASP.NET JSON dates of the form `/Date(1772600400000)/` into `Date`.
///
/// The value is epoch milliseconds (may be negative). The portal uses
/// `-62135578800000` (.NET `DateTime.MinValue`) to mean "no date"; callers should
/// treat pre-epoch results as absent.
enum DotNetDate {

    private static let pattern = try? NSRegularExpression(pattern: #"/Date\((-?\d+)\)/"#)

    static func parse(_ raw: String?) -> Date? {
        guard let raw, let regex = pattern else { return nil }
        let range = NSRange(raw.startIndex..<raw.endIndex, in: raw)
        guard let match = regex.firstMatch(in: raw, range: range),
              let millisRange = Range(match.range(at: 1), in: raw),
              let millis = Double(raw[millisRange]) else {
            return nil
        }
        let date = Date(timeIntervalSince1970: millis / 1000)
        // Drop .NET DateTime.MinValue and other pre-epoch sentinels.
        return date.timeIntervalSince1970 <= 0 ? nil : date
    }
}
