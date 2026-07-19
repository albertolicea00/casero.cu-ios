import Foundation

/// Extracts the ASP.NET anti-forgery form token embedded in every portal page.
enum AntiForgery {

    private static let pattern = #"name="__RequestVerificationToken"[^>]*value="([^"]+)""#

    static func extract(from html: String) throws -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw PortalError.antiForgeryMissing
        }
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              let valueRange = Range(match.range(at: 1), in: html) else {
            throw PortalError.antiForgeryMissing
        }
        let token = String(html[valueRange])
        if token.isEmpty { throw PortalError.antiForgeryMissing }
        return token
    }
}
