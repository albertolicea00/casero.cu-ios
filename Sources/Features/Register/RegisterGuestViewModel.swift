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
    @Published var checkOut = PortalDates.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    @Published private(set) var foundPerson: PersonaValidation?
    @Published private(set) var queue: [GuestRegistration] = []
    @Published private(set) var isLookingUp = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSubmission: [Guest]?
    @Published private(set) var isSessionExpired = false

    private let client: any PortalServing

    init(client: any PortalServing) {
        self.client = client
    }

    var canLookUp: Bool {
        !identificador.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLookingUp && !isSubmitting
    }

    var validationMessage: String? {
        guard let person = foundPerson else { return nil }
        if let response = person.response, !response.isEmpty, response != "OK" { return response }
        let fields = [person.firstName, person.identificador, person.nationalityCode ?? "", person.sex ?? ""]
        if fields.contains(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            || person.birthDate == nil
        {
            return String(
                localized:
                    "The portal returned incomplete personal data. Use the official portal to complete this registration."
            )
        }
        let wireFields = fields + [person.lastName1 ?? "", person.lastName2 ?? "", person.middleName ?? ""]
        if wireFields.contains(where: { $0.contains(where: { ",|*\n\r".contains($0) }) }) {
            return String(localized: "Personal data contains unsupported characters. Use the official portal.")
        }
        if checkOut < checkIn { return String(localized: "Check-out must be on or after check-in.") }
        if queue.contains(where: { $0.identificador.caseInsensitiveCompare(person.identificador) == .orderedSame }) {
            return String(localized: "This person is already in the registration queue.")
        }
        return nil
    }

    var canAdd: Bool { foundPerson != nil && validationMessage == nil && !isSubmitting }

    /// Nationality code the portal returns for Cuban companions (`ValidarPersonaSuin`).
    private static let cubanNationalityCode = "247"

    /// Captured traffic only shows companions registered in the same call as a
    /// foreign guest (the companion's `EstanciaId` is `<guest stay>.1`), so a
    /// queue of companions alone is never sent.
    var submitBlockedMessage: String? {
        guard !queue.isEmpty,
            queue.allSatisfy({ $0.nationalityCode == Self.cubanNationalityCode })
        else { return nil }
        return String(localized: "Add the foreign guest to the queue before registering companions.")
    }

    var canSubmit: Bool {
        !queue.isEmpty && !isSubmitting && submitBlockedMessage == nil
    }

    func lookUp() async {
        guard canLookUp else { return }
        errorMessage = nil
        foundPerson = nil
        isLookingUp = true
        defer { isLookingUp = false }
        let trimmed = identificador.trimmingCharacters(in: .whitespaces)
        let kind = lookupKind
        do {
            let person: PersonaValidation
            switch kind {
            case .foreignGuest:
                let tipo: PersonaLookup = trimmed.contains("_") ? .byName : .byPassport
                person = try await client.validatePersonaDiie(identificador: trimmed, tipo: tipo)
            case .cubanCompanion:
                person = try await client.validatePersonaSuin(identificador: trimmed)
            }
            guard kind == lookupKind, trimmed == identificador.trimmingCharacters(in: .whitespaces) else { return }
            foundPerson = person
        } catch is CancellationError {
            return
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Queues the currently found person with the selected stay dates, then clears the lookup.
    func addToQueue() {
        guard canAdd, let person = foundPerson, let birthDate = person.birthDate else { return }
        let registration = GuestRegistration(
            firstName: [person.firstName, person.middleName ?? ""].filter { !$0.isEmpty }.joined(separator: " "),
            lastName1: person.lastName1 ?? "",
            lastName2: person.lastName2 ?? "",
            identificador: person.identificador,
            nationalityCode: person.nationalityCode ?? "",
            sex: person.sex ?? "",
            birthDate: birthDate,
            checkIn: checkIn,
            checkOut: checkOut,
            procedenciaCode: person.nationalityCode ?? "",
        )
        queue.append(registration)
        foundPerson = nil
        identificador = ""
    }

    func removeFromQueue(_ offsets: IndexSet) {
        guard !isSubmitting else { return }
        queue.remove(atOffsets: offsets)
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        lastSubmission = nil
        defer { isSubmitting = false }
        do {
            let result = try await client.registerGuests(queue)
            lastSubmission = result
            let accepted = Set(
                result.filter { $0.response == "OK" && !$0.identificador.isEmpty }.map { $0.identificador.uppercased() }
            )
            queue.removeAll { accepted.contains($0.identificador.uppercased()) }
            if !queue.isEmpty {
                errorMessage = String(
                    localized:
                        "Some registrations were not confirmed. They remain in the queue. Verify the portal before retrying to avoid duplicate reports."
                )
            }
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearLookup() {
        foundPerson = nil
        errorMessage = nil
    }

    func acknowledgeSessionExpired() {
        isSessionExpired = false
    }
}
