import Foundation

/// Response of `Huespedes/ValidarPersonaDiie` (foreign guests, DIIE registry) and
/// `Huespedes/ValidarPersonaSuin` (Cuban companions, SUIN/carné registry).
struct PersonaValidation: Decodable {
    let idPersona: String?
    let identificador: String
    let firstName: String
    let middleName: String?
    let lastName1: String?
    let lastName2: String?
    let fullName: String
    let sex: String?
    let birthDate: Date?
    let nationalityCode: String?
    let nationality: String?
    /// Present for DIIE lookups: e.g. "Entrada" if the person is currently checked in elsewhere.
    let status: String?
    let response: String?

    private enum CodingKeys: String, CodingKey {
        case idPersona = "IdPersona"
        case identificador = "Identificador"
        case firstName = "Nombre"
        case middleName = "Nombre2"
        case lastName1 = "Apellido1"
        case lastName2 = "Apellido2"
        case fullName = "Biografico"
        case sex = "Sexo"
        case birthDate = "FechaNac"
        case nationalityCode = "Nacionalidad"
        case nationality = "DescNacionalidad"
        case status = "Estado"
        case response = "Respuesta"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idPersona = try? container.decode(String.self, forKey: .idPersona)
        identificador = (try? container.decode(String.self, forKey: .identificador)) ?? ""
        firstName = (try? container.decode(String.self, forKey: .firstName)) ?? ""
        middleName = try? container.decode(String.self, forKey: .middleName)
        lastName1 = try? container.decode(String.self, forKey: .lastName1)
        lastName2 = try? container.decode(String.self, forKey: .lastName2)
        fullName = (try? container.decode(String.self, forKey: .fullName)) ?? ""
        sex = try? container.decode(String.self, forKey: .sex)
        birthDate = DotNetDate.parse(try? container.decode(String.self, forKey: .birthDate))
        nationalityCode = try? container.decode(String.self, forKey: .nationalityCode)
        nationality = try? container.decode(String.self, forKey: .nationality)
        status = try? container.decode(String.self, forKey: .status)
        response = try? container.decode(String.self, forKey: .response)
    }
}

/// A person queued for `Huespedes/RegistrarHuesped`, built from a validated
/// `PersonaValidation` plus the stay's dates.
///
/// Portal wire format (one entry, `|`-joined for multiple):
/// `NOMBRE**APELLIDO1*APELLIDO2,IDENTIFICADOR,NACIONALIDAD,SEXO,dd/MM/yy(nac),dd/MM/yy(entrada),dd/MM/yy(salida),PROCEDENCIA`
struct GuestRegistration {
    let firstName: String
    let lastName1: String
    let lastName2: String
    let identificador: String
    let nationalityCode: String
    let sex: String
    let birthDate: Date
    let checkIn: Date
    let checkOut: Date
    /// Country/origin code. The captured traffic always sends this equal to
    /// `nationalityCode`; kept separate in case the portal expects a distinct
    /// "coming from" code for connecting itineraries — unverified.
    let procedenciaCode: String

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()

    /// Encodes one `personas` segment. `**` separates first/last1, `*` separates last1/last2.
    var wireFormat: String {
        [
            "\(firstName)**\(lastName1)*\(lastName2)",
            identificador,
            nationalityCode,
            sex,
            Self.dateFormatter.string(from: birthDate),
            Self.dateFormatter.string(from: checkIn),
            Self.dateFormatter.string(from: checkOut),
            procedenciaCode,
        ].joined(separator: ",")
    }
}
