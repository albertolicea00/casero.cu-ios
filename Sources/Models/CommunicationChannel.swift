import Foundation

/// One entry of `ViasComunicacion/ListarViasComunicacion`: `{ "Tipo": "sms", "Valor": "+535XXXXXXX" }`.
struct CommunicationChannel: Decodable, Hashable {
    let kind: String
    let value: String

    /// Phones come back as `Tipo: "sms"`. The e-mail `Tipo` was never captured, so
    /// anything else is treated as an e-mail address.
    var isPhone: Bool { kind.lowercased() == "sms" }

    private enum CodingKeys: String, CodingKey {
        case kind = "Tipo"
        case value = "Valor"
    }
}
