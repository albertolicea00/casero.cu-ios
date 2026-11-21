import XCTest

@testable import CaseroCu

@MainActor
final class RegistrationTests: XCTestCase {
    func testMissingBirthDateCannotBeQueued() async throws {
        let client = StubPortalClient()
        client.person = try fixturePerson(birthDate: nil)
        let model = RegisterGuestViewModel(client: client)
        model.identificador = "TEST-A"
        await model.lookUp()
        XCTAssertFalse(model.canAdd)
        XCTAssertNotNil(model.validationMessage)
        model.addToQueue()
        XCTAssertTrue(model.queue.isEmpty)
    }

    func testDuplicateQueueAndInvalidDatesAreRejected() async throws {
        let client = StubPortalClient()
        client.person = try fixturePerson()
        let model = RegisterGuestViewModel(client: client)
        model.identificador = "TEST-A"
        await model.lookUp()
        model.checkOut = model.checkIn.addingTimeInterval(-86400)
        XCTAssertFalse(model.canAdd)
        model.checkOut = model.checkIn.addingTimeInterval(86400)
        model.addToQueue()
        model.identificador = "TEST-A"
        await model.lookUp()
        XCTAssertFalse(model.canAdd)
        model.addToQueue()
        XCTAssertEqual(model.queue.count, 1)
    }

    /// A Cuban living abroad is found by passport and is a main guest; only people
    /// found by CI count as companions.
    func testCompanionRuleFollowsLookupNotNationality() async throws {
        let client = StubPortalClient()
        let json = #"{"Nombre":"Test","Apellido1":"Guest","Biografico":"Test Guest","Identificador":"X1","Nacionalidad":"247","Sexo":"F","FechaNac":"/Date(0)/"}"#
        client.person = try JSONDecoder().decode(PersonaValidation.self, from: Data(json.utf8))
        let model = RegisterGuestViewModel(client: client)
        model.lookupKind = .foreignGuest
        model.identificador = "X1"
        await model.lookUp()
        model.addToQueue()
        XCTAssertNil(model.companionWarning)
        XCTAssertTrue(model.canSubmit)

        let companions = RegisterGuestViewModel(client: client)
        companions.lookupKind = .cubanCompanion
        companions.identificador = "00000000001"
        await companions.lookUp()
        companions.addToQueue()
        XCTAssertNotNil(companions.companionWarning)
        XCTAssertTrue(companions.canSubmit, "Warning only: the portal decides")
    }

    func testPartialSuccessRetainsRejectedPeople() async throws {
        let client = StubPortalClient()
        let model = RegisterGuestViewModel(client: client)
        for id in ["TEST-A", "TEST-B"] {
            client.person = try fixturePerson(id: id)
            model.identificador = id
            await model.lookUp()
            model.addToQueue()
        }
        client.results = [try fixtureGuest(), try fixtureGuest(id: "TEST-B", response: "Rejected")]
        await model.submit()
        XCTAssertEqual(model.queue.map(\.identificador), ["TEST-B"])
        XCTAssertNotNil(model.errorMessage)
    }

    func testUncertainTransportFailureDoesNotLoseQueue() async throws {
        let client = StubPortalClient()
        client.person = try fixturePerson()
        let model = RegisterGuestViewModel(client: client)
        model.identificador = "TEST-A"
        await model.lookUp()
        model.addToQueue()
        client.submitError = PortalError.unreachable
        await model.submit()
        XCTAssertEqual(model.queue.count, 1)
        XCTAssertEqual(client.submissions, 1)
    }
}

final class StubPortalClient: PortalServing {
    var person: PersonaValidation!
    var results: [Guest] = []
    var submitError: Error?
    var submissions = 0
    func validatePersonaDiie(identificador: String, tipo: PersonaLookup) async throws -> [PersonaValidation] { [person] }
    func validatePersonaSuin(identificador: String) async throws -> [PersonaValidation] { [person] }
    func registerGuests(_ people: [GuestRegistration]) async throws -> [Guest] {
        submissions += 1
        if let submitError { throw submitError }
        return results
    }
    func listGuests(from: Date, to: Date, pageSize: Int, page: Int) async throws -> [Guest] { results }
    func signOut() async {}
}
