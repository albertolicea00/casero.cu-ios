import Foundation

@MainActor
final class RegisterGuestViewModel: ObservableObject {

    /// Order matches the segmented selector: passport, CI, names, temporary CI.
    enum LookupKind: CaseIterable, Identifiable {
        case foreignGuest
        case cubanCompanion
        case foreignGuestByName
        case temporaryCarne
        var id: Self { self }

        /// Short segment title.
        var segmentLabel: String {
            switch self {
            case .foreignGuest: "Passport"
            case .cubanCompanion: "ID card"
            case .foreignGuestByName: "Name"
            case .temporaryCarne: "Temp. ID"
            }
        }

        var fieldLabel: String {
            switch self {
            case .foreignGuest: "Passport number"
            case .cubanCompanion: "Carné de identidad"
            case .foreignGuestByName: "First name"
            case .temporaryCarne: "Temporary carné number"
            }
        }

        var help: String {
            switch self {
            case .foreignGuest:
                "This search option is only valid for foreigners and Cubans who are permanent residents abroad."
            case .cubanCompanion:
                "This search option is only valid for Cuban nationals."
            case .foreignGuestByName:
                "This search option is only valid for foreigners and Cubans who are permanent residents abroad."
            case .temporaryCarne:
                "This search option is only valid for foreigners who are permanent or temporary residents in Cuba."
            }
        }
    }

    @Published var lookupKind: LookupKind = .foreignGuest
    @Published var identificador = ""
    /// Name lookup fields, mirroring the portal form: first name, first and second surname.
    @Published var firstName = ""
    @Published var lastName1 = ""
    @Published var lastName2 = ""
    @Published var checkIn = Date()
    @Published var checkOut = PortalDates.calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    @Published private(set) var foundPerson: PersonaValidation?
    /// Several matches (possible for a name lookup); the user picks one.
    @Published private(set) var candidates: [PersonaValidation] = []
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

    /// What is sent as `identificador`. Name lookups are joined with underscores,
    /// as captured from the portal: `NOMBRE_APELLIDO1_APELLIDO2`. An empty second
    /// surname keeps the trailing underscore (`NOMBRE_APELLIDO1_`), which the portal
    /// also matches.
    var lookupQuery: String {
        switch lookupKind {
        case .foreignGuestByName:
            [firstName, lastName1, lastName2]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
                .joined(separator: "_")
        default:
            identificador.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    var canLookUp: Bool {
        let hasQuery =
            lookupKind == .foreignGuestByName
            ? ![firstName, lastName1].contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            : !lookupQuery.isEmpty
        return hasQuery && !isLookingUp && !isSubmitting
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
        candidates = []
        isLookingUp = true
        defer { isLookingUp = false }
        let query = lookupQuery
        let kind = lookupKind
        do {
            let people: [PersonaValidation]
            switch kind {
            case .foreignGuest:
                people = try await client.validatePersonaDiie(identificador: query, tipo: .byPassport)
            case .foreignGuestByName:
                people = try await client.validatePersonaDiie(identificador: query, tipo: .byName)
            case .temporaryCarne:
                people = try await client.validatePersonaDiie(identificador: query, tipo: .byTemporaryCarne)
            case .cubanCompanion:
                people = try await client.validatePersonaSuin(identificador: query)
            }
            guard kind == lookupKind, query == lookupQuery else { return }
            switch people.count {
            case 0: errorMessage = String(localized: "Person not found.")
            case 1: foundPerson = people[0]
            default: candidates = people
            }
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

    func select(_ person: PersonaValidation) {
        candidates = []
        foundPerson = person
    }

    func clearLookup() {
        foundPerson = nil
        candidates = []
        errorMessage = nil
    }

    func acknowledgeSessionExpired() {
        isSessionExpired = false
    }
}
