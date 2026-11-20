import Foundation

/// Reporting dates belong to the lodging location even when the device travels.
enum PortalDates {
    static let timeZone = TimeZone(identifier: "America/Havana")!
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func display(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
