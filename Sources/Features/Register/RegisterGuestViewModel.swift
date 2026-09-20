import Foundation

@MainActor
final class RegisterGuestViewModel: ObservableObject {

    enum LookupKind: String, CaseIterable, Identifiable {
        case foreignGuest = "Foreign guest (passport)"
        case cubanCompanion = "Cuban companion (carné)"
        var id: String { rawValue }
    }

    @Published var lookupKind: LookupKind = .foreignGuest
    @Published var identificador = ""
    @Published var checkIn = Date()
    @Published var checkOut = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    @Published private(set) var foundPerson: PersonaValidation?
    @Published private(set) var queue: [GuestRegistration] = []
    @Published private(set) var isLookingUp = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSubmission: [Guest]?
    @Published private(set) var isSessionExpired = false

    private let client: CaseroClient

    init(client: CaseroClient) {
        self.client = client
    }

    var canLookUp: Bool {
        !identificador.trimmingCharacters(in: .whitespaces).isEmpty && !isLookingUp
    }

    var canSubmit: Bool {
        !queue.isEmpty && !isSubmitting
    }

    func lookUp() async {
        errorMessage = nil
        foundPerson = nil
        isLookingUp = true
        defer { isLookingUp = false }
        let trimmed = identificador.trimmingCharacters(in: .whitespaces)
        do {
            switch lookupKind {
            case .foreignGuest:
                let tipo: PersonaLookup = trimmed.contains("_") ? .byName : .byPassport
                foundPerson = try await client.validatePersonaDiie(identificador: trimmed, tipo: tipo)
            case .cubanCompanion:
                foundPerson = try await client.validatePersonaSuin(identificador: trimmed)
            }
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Queues the currently found person with the selected stay dates, then clears the lookup.
    func addToQueue() {
        guard let person = foundPerson, checkOut >= checkIn else { return }
        let registration = GuestRegistration(
            firstName: person.firstName,
            lastName1: person.lastName1 ?? "",
            lastName2: person.lastName2 ?? "",
            identificador: person.identificador,
            nationalityCode: person.nationalityCode ?? "",
            sex: person.sex ?? "",
            birthDate: person.birthDate ?? Date(timeIntervalSince1970: 0),
            checkIn: checkIn,
            checkOut: checkOut,
            procedenciaCode: person.nationalityCode ?? "",
        )
        queue.append(registration)
        foundPerson = nil
        identificador = ""
    }

    func removeFromQueue(_ offsets: IndexSet) {
        queue.remove(atOffsets: offsets)
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let result = try await client.registerGuests(queue)
            lastSubmission = result
            queue.removeAll()
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    func acknowledgeSessionExpired() {
        isSessionExpired = false
    }
}
