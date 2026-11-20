import Foundation

/// One guest as returned by `Huespedes/ListarHuespedes`.
///
/// Portal JSON keys are PascalCase and dates arrive as `/Date(ms)/` strings, so
/// this decodes manually. Foreign guests are identified by passport
/// (`identificador`); nationality arrives as a numeric code plus a display name.
struct Guest: Codable, Identifiable {
    let fullName: String
    let identificador: String
    let checkIn: Date?
    let checkOut: Date?
    let birthDate: Date?
    let nationalityCode: String?
    let nationality: String?
    let sex: String?
    let stayId: String
    let companionId: String?
    /// Present on `RegistrarHuesped` responses: "OK" or an error message per person.
    let response: String?

    var id: String { "\(stayId)|\(identificador)|\(checkIn?.timeIntervalSince1970 ?? 0)" }

    func birthDateForDisplay(assumingCuban: Bool = false) -> Date? {
        if let birthDate { return birthDate }
        let isCuban =
            assumingCuban || nationality?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() == "CUBA"
        guard isCuban else { return nil }
        return CubanIdentity.birthDate(from: identificador)
    }

    private enum CodingKeys: String, CodingKey {
        case fullName = "Biografico"
        case identificador = "Identificador"
        case checkIn = "FechaEntrada"
        case checkOut = "FechaSalida"
        case birthDate = "FechaNacimiento"
        case nationalityCode = "Nacionalidad"
        case nationality = "DescNacionalidad"
        case sex = "Sexo"
        case stayId = "EstanciaId"
        case companionId = "Id"
        case response = "Respuesta"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(fullName, forKey: .fullName)
        try container.encode(identificador, forKey: .identificador)
        try container.encodeIfPresent(checkIn.map(DotNetDate.string), forKey: .checkIn)
        try container.encodeIfPresent(checkOut.map(DotNetDate.string), forKey: .checkOut)
        try container.encodeIfPresent(birthDate.map(DotNetDate.string), forKey: .birthDate)
        try container.encodeIfPresent(nationalityCode, forKey: .nationalityCode)
        try container.encodeIfPresent(nationality, forKey: .nationality)
        try container.encodeIfPresent(sex, forKey: .sex)
        try container.encode(stayId, forKey: .stayId)
        try container.encodeIfPresent(companionId, forKey: .companionId)
        try container.encodeIfPresent(response, forKey: .response)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullName = (try? container.decode(String.self, forKey: .fullName)) ?? ""
        identificador = (try? container.decode(String.self, forKey: .identificador)) ?? ""
        checkIn =
            DotNetDate.parse(try? container.decode(String.self, forKey: .checkIn))
            ?? (try? container.decode(Date.self, forKey: .checkIn))
        checkOut =
            DotNetDate.parse(try? container.decode(String.self, forKey: .checkOut))
            ?? (try? container.decode(Date.self, forKey: .checkOut))
        birthDate =
            DotNetDate.parse(try? container.decode(String.self, forKey: .birthDate))
            ?? (try? container.decode(Date.self, forKey: .birthDate))
        nationalityCode = try? container.decode(String.self, forKey: .nationalityCode)
        nationality = try? container.decode(String.self, forKey: .nationality)
        sex = try? container.decode(String.self, forKey: .sex)
        stayId = (try? container.decode(String.self, forKey: .stayId)) ?? ""
        if let stringId = try? container.decode(String.self, forKey: .companionId) {
            companionId = stringId
        } else if let numericId = try? container.decode(Int.self, forKey: .companionId) {
            companionId = String(numericId)
        } else {
            companionId = nil
        }
        response = try? container.decode(String.self, forKey: .response)
        guard !identificador.isEmpty, !fullName.isEmpty else { throw PortalError.invalidResponse }
    }
}

enum CubanIdentity {
    static func birthDate(from identityNumber: String) -> Date? {
        let digits = Array(identityNumber.filter(\.isNumber))
        guard digits.count == 11,
            let yearPart = Int(String(digits[0...1])),
            let month = Int(String(digits[2...3])),
            let day = Int(String(digits[4...5])),
            let centuryCode = digits[6].wholeNumberValue
        else { return nil }

        let year: Int
        switch centuryCode {
        case 0...5: year = 1900 + yearPart
        case 6...8: year = 2000 + yearPart
        case 9: year = 1800 + yearPart
        default: return nil
        }

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        guard let date = PortalDates.calendar.date(from: components) else { return nil }
        let parsed = PortalDates.calendar.dateComponents([.year, .month, .day], from: date)
        guard parsed.year == year, parsed.month == month, parsed.day == day else { return nil }
        return date
    }
}

/// Envelope returned by `Huespedes/ListarHuespedes`.
struct GuestListResponse: Decodable {
    let error: String
    let page: Int
    let total: Int
    let guests: [Guest]

    private enum CodingKeys: String, CodingKey {
        case error = "Error"
        case page = "Pagina"
        case total = "Total"
        case guests = "ListaHuespedes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? container.decode(String.self, forKey: .error)) ?? ""
        page = (try? container.decode(Int.self, forKey: .page)) ?? 1
        total = (try? container.decode(Int.self, forKey: .total)) ?? 0
        guard error.isEmpty else { throw PortalError.rejected(error) }
        guests = try container.decode([Guest].self, forKey: .guests)
    }
}
