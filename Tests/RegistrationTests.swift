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
