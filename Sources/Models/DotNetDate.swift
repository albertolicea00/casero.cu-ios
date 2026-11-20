import Foundation

/// ASP.NET dates use UTC milliseconds; only DateTime.MinValue is absent.
enum DotNetDate {
    private static let pattern = try! NSRegularExpression(pattern: #"^/Date\((-?\d+)(?:[+-]\d{4})?\)/$"#)

    static func parse(_ raw: String?) -> Date? {
        guard let raw,
            let match = pattern.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)),
            let range = Range(match.range(at: 1), in: raw),
            let millis = Double(raw[range]), millis > -62_135_578_800_000
        else { return nil }
        return Date(timeIntervalSince1970: millis / 1000)
    }

    static func string(_ date: Date) -> String {
        "/Date(\(Int64((date.timeIntervalSince1970 * 1000).rounded())))/"
    }
}
