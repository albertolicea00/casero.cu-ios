import Foundation

/// Feature boundary used by tests without contacting the real portal.
protocol PortalServing {
    func listGuests(from: Date, to: Date, pageSize: Int, page: Int) async throws -> [Guest]
    func validatePersonaDiie(identificador: String, tipo: PersonaLookup) async throws -> PersonaValidation
    func validatePersonaSuin(identificador: String) async throws -> PersonaValidation
    func registerGuests(_ people: [GuestRegistration]) async throws -> [Guest]
    func signOut() async
}
