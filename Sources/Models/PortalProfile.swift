import Foundation

/// The host's account as shown on `GET /Cuenta/Perfil`. The page renders it as an HTML
/// table of `td.titulo` / `td.texto` pairs inside `div.perfil`; there is no JSON endpoint.
struct PortalProfile: Equatable {
    var firstName = ""
    var secondName = ""
    var lastName1 = ""
    var lastName2 = ""
    var identityNumber = ""
    var province = ""
    var municipality = ""
    var username = ""
    var address = ""

    var fullName: String {
        [firstName, secondName, lastName1, lastName2].filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Reads the profile table. Throws `invalidResponse` when the page has no profile
    /// block (for example the login page served instead of the profile).
    static func parse(html: String) throws -> PortalProfile {
        guard let start = html.range(of: #"class="[^"]*\bperfil\b[^"]*""#, options: .regularExpression) else {
            throw PortalError.invalidResponse
        }
        // The password form follows the profile block; stop there.
        let end = html.range(of: "<form", range: start.upperBound..<html.endIndex)?.lowerBound ?? html.endIndex
        let block = String(html[start.upperBound..<end])

        let cell = try NSRegularExpression(
            pattern: #"<td\b([^>]*)>(.*?)</td>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
        var profile = PortalProfile()
        var label: String?
        var found = false
        for match in cell.matches(in: block, range: NSRange(block.startIndex..<block.endIndex, in: block)) {
            guard let attributes = Range(match.range(at: 1), in: block), let content = Range(match.range(at: 2), in: block)
            else { continue }
            let text = plainText(String(block[content]))
            if block[attributes].contains("titulo") {
                label = text
            } else if block[attributes].contains("texto"), let current = label {
                label = nil
                if profile.assign(text, to: current) { found = true }
            }
        }
        guard found else { throw PortalError.invalidResponse }
        return profile
    }

    /// Returns whether the label is a known profile field.
    private mutating func assign(_ value: String, to label: String) -> Bool {
        let key = label.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
        switch key {
        case "primer nombre": firstName = value
        case "segundo nombre": secondName = value
        case "primer apellido": lastName1 = value
        case "segundo apellido": lastName2 = value
        case "ci": identityNumber = value
        case "provincia": province = value
        case "municipio": municipality = value
        case "usuario": username = value
        case "direccion": address = value
        default: return false
        }
        return true
    }

    /// Drops inner tags, decodes the entities the portal uses and collapses whitespace.
    private static func plainText(_ html: String) -> String {
        var text = html.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        let named = [
            "&aacute;": "á", "&eacute;": "é", "&iacute;": "í", "&oacute;": "ó", "&uacute;": "ú",
            "&Aacute;": "Á", "&Eacute;": "É", "&Iacute;": "Í", "&Oacute;": "Ó", "&Uacute;": "Ú",
            "&ntilde;": "ñ", "&Ntilde;": "Ñ", "&uuml;": "ü", "&Uuml;": "Ü", "&nbsp;": " ",
            "&quot;": "\"", "&#39;": "'", "&lt;": "<", "&gt;": ">",
        ]
        for (entity, character) in named { text = text.replacingOccurrences(of: entity, with: character) }
        if let numeric = try? NSRegularExpression(pattern: #"&#(x?)([0-9a-fA-F]+);"#) {
            for match in numeric.matches(in: text, range: NSRange(text.startIndex..<text.endIndex, in: text)).reversed() {
                guard let whole = Range(match.range, in: text), let digits = Range(match.range(at: 2), in: text)
                else { continue }
                let isHex = match.range(at: 1).length > 0
                if let code = UInt32(text[digits], radix: isHex ? 16 : 10), let scalar = Unicode.Scalar(code) {
                    text.replaceSubrange(whole, with: String(Character(scalar)))
                }
            }
        }
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
