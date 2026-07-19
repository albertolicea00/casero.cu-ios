import Foundation

/// One guest as returned by `Huespedes/ListarHuespedes`.
///
/// Portal JSON keys are PascalCase and dates arrive as `/Date(ms)/` strings, so
/// this decodes manually. Foreign guests are identified by passport
/// (`identificador`); nationality arrives as a numeric code plus a display name.
struct Guest: Decodable, Identifiable {
    let fullName: String
    let identificador: String
    let checkIn: Date?
    let checkOut: Date?
    let birthDate: Date?
    let nationalityCode: String?
    let nationality: String?
    let sex: String?
    let stayId: String

    var id: String { stayId }

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
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fullName = (try? container.decode(String.self, forKey: .fullName)) ?? ""
        identificador = (try? container.decode(String.self, forKey: .identificador)) ?? ""
        checkIn = DotNetDate.parse(try? container.decode(String.self, forKey: .checkIn))
        checkOut = DotNetDate.parse(try? container.decode(String.self, forKey: .checkOut))
        birthDate = DotNetDate.parse(try? container.decode(String.self, forKey: .birthDate))
        nationalityCode = try? container.decode(String.self, forKey: .nationalityCode)
        nationality = try? container.decode(String.self, forKey: .nationality)
        sex = try? container.decode(String.self, forKey: .sex)
        stayId = (try? container.decode(String.self, forKey: .stayId)) ?? ""
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
        guests = (try? container.decode([Guest].self, forKey: .guests)) ?? []
    }
}
