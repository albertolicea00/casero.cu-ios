import Foundation

/// Reads the token independently of attribute order and HTML quote style.
enum AntiForgery {
    static func extract(from html: String) throws -> String {
        let inputs = try NSRegularExpression(pattern: #"<input\b[^>]*>"#, options: .caseInsensitive)
        let attributes = try NSRegularExpression(pattern: #"([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#)
        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        for input in inputs.matches(in: html, range: range) {
            guard let inputRange = Range(input.range, in: html) else { continue }
            let tag = String(html[inputRange])
            var values: [String: String] = [:]
            for attribute in attributes.matches(in: tag, range: NSRange(tag.startIndex..<tag.endIndex, in: tag)) {
                guard let name = Range(attribute.range(at: 1), in: tag) else { continue }
                for index in 2...4 {
                    if let value = Range(attribute.range(at: index), in: tag) {
                        values[String(tag[name]).lowercased()] = String(tag[value])
                        break
                    }
                }
            }
            if values["name"] == "__RequestVerificationToken", let token = values["value"], !token.isEmpty {
                return token.replacingOccurrences(of: "&quot;", with: "\"")
                    .replacingOccurrences(of: "&#39;", with: "'")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                    .replacingOccurrences(of: "&amp;", with: "&")
            }
        }
        throw PortalError.antiForgeryMissing
    }
}
