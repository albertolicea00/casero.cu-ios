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

    /// The person being reviewed in the result sheet (dates + Add to registration).
    @Published private(set) var foundPerson: PersonaValidation?
    /// Every lookup result. Several are listed in the sheet to pick from first.
    @Published private(set) var candidates: [PersonaValidation] = []
    /// How the current results were found (the selector can change afterwards).
    private var resultKind: LookupKind?

    /// The result sheet is open while there is something to pick or review.
    var isShowingResult: Bool { foundPerson != nil || !candidates.isEmpty }
    @Published private(set) var queue: [GuestRegistration] = []
    @Published private(set) var isLookingUp = false
    @Published private(set) var isSubmitting = false
    /// Shown under the Look up button.
    @Published private(set) var lookupErrorMessage: String?
    /// Registration errors, shown with the queue.
    @Published private(set) var errorMessage: String?
    @Published private(set) var lastSubmission: [Guest]?
    /// Queued people whose registration was sent but never confirmed (answer lost).
    @Published private(set) var uncertainIDs: Set<String> = []
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

    /// The portal accepts check-ins up to 7 days back (today the 21st → the 14th),
    /// counted in Cuba time.
    nonisolated static let maxCheckInDaysBack = 7

    nonisolated static func earliestCheckIn(now: Date = .now) -> Date {
        let calendar = PortalDates.calendar
        let today = calendar.startOfDay(for: now)
        return calendar.date(byAdding: .day, value: -maxCheckInDaysBack, to: today) ?? today
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
        if PortalDates.calendar.startOfDay(for: checkIn) < Self.earliestCheckIn() {
            return String(localized: "Check-in can be at most 7 days ago.")
        }
        if queue.contains(where: { $0.identificador.caseInsensitiveCompare(person.identificador) == .orderedSame }) {
            return String(localized: "This person is already in the registration queue.")
        }
        return nil
    }

    var canAdd: Bool { foundPerson != nil && validationMessage == nil && !isSubmitting }

    /// Captured traffic only shows companions registered in the same call as a
    /// main guest (the companion's `EstanciaId` is `<guest stay>.1`). A queue of
    /// companions alone gets a warning but is still sent: the portal decides and
    /// its answer is shown. Companions are people found by CI, not by nationality.
    var companionWarning: String? {
        guard !queue.isEmpty, queue.allSatisfy(\.isCompanion) else { return nil }
        return String(localized: "Add the main guest to the queue before registering companions.")
    }

    var canSubmit: Bool {
        !queue.isEmpty && !isSubmitting
    }

    func lookUp() async {
        guard canLookUp else { return }
        lookupErrorMessage = nil
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
            // Results open in a sheet. A single match goes straight to its card;
            // several are listed first so the host picks the right person.
            if people.isEmpty {
                lookupErrorMessage =
                    kind == .foreignGuestByName
                    ? String(localized: "Not found. If the person has a second given name, try without it.")
                    : String(localized: "Person not found.")
            } else {
                resultKind = kind
                candidates = people
                if people.count == 1 { foundPerson = people[0] }
            }
        } catch is CancellationError {
            return
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch PortalError.rejected(let message) where kind == .foreignGuestByName {
            // The portal matches the first given name only; suggest dropping the second.
            lookupErrorMessage = message + " " + String(localized: "If the person has a second given name, try without it.")
        } catch {
            lookupErrorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
    }

    /// Queues the currently found person with the selected stay dates, then clears the lookup.
    func addToQueue() {
        guard canAdd, let person = foundPerson, let birthDate = person.birthDate else { return }
        let registration = GuestRegistration(
            firstName: person.firstName,
            middleName: person.middleName ?? "",
            lastName1: person.lastName1 ?? "",
            lastName2: person.lastName2 ?? "",
            identificador: person.identificador,
            nationalityCode: person.nationalityCode ?? "",
            sex: person.sex ?? "",
            birthDate: birthDate,
            checkIn: checkIn,
            checkOut: checkOut,
            procedenciaCode: person.nationalityCode ?? "",
            nationalityName: person.nationality,
            isCompanion: resultKind == .cubanCompanion,
        )
        queue.append(registration)
        foundPerson = nil
        candidates = []
        identificador = ""
        firstName = ""
        lastName1 = ""
        lastName2 = ""
    }

    func removeFromQueue(_ offsets: IndexSet) {
        guard !isSubmitting else { return }
        for index in offsets { uncertainIDs.remove(queue[index].identificador.uppercased()) }
        queue.remove(atOffsets: offsets)
    }

    /// Returns `true` when the portal accepted at least one person.
    @discardableResult
    func submit() async -> Bool {
        guard canSubmit else { return false }
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
            uncertainIDs.subtract(accepted)
            if !queue.isEmpty {
                errorMessage = String(
                    localized:
                        "Some registrations were not confirmed. They remain in the queue. Verify the portal before retrying to avoid duplicate reports."
                )
            }
            return !accepted.isEmpty
        } catch PortalError.sessionExpired {
            isSessionExpired = true
        } catch PortalError.registrationUncertain {
            uncertainIDs.formUnion(queue.map { $0.identificador.uppercased() })
            errorMessage = PortalError.registrationUncertain.errorDescription
        } catch {
            errorMessage = (error as? PortalError)?.errorDescription ?? error.localizedDescription
        }
        return false
    }

    func isUncertain(_ entry: GuestRegistration) -> Bool {
        uncertainIDs.contains(entry.identificador.uppercased())
    }

    /// Closes the result sheet without adding anyone.
    func dismissResult() {
        foundPerson = nil
        candidates = []
    }

    func select(_ person: PersonaValidation) {
        foundPerson = person
    }


    func clearLookup() {
        foundPerson = nil
        candidates = []
        lookupErrorMessage = nil
    }

    func acknowledgeSessionExpired() {
        isSessionExpired = false
    }
}
