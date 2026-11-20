import XCTest

@testable import CaseroCu

final class ModelTests: XCTestCase {
    func testPortalDatesKeepBirthDatesBefore1970() {
        XCTAssertNotNil(DotNetDate.parse("/Date(-315619200000)/"))
        XCTAssertEqual(DotNetDate.parse("/Date(0)/"), Date(timeIntervalSince1970: 0))
        XCTAssertNil(DotNetDate.parse("/Date(-62135578800000)/"))
        XCTAssertNil(DotNetDate.parse("invalid"))
    }

    func testCacheRoundTripRetainsAllDates() throws {
        let guest = try fixtureGuest()
        let snapshot = GuestCache.Snapshot(
            fetchedAt: Date(), guests: [guest], rangeStart: guest.checkIn, rangeEnd: guest.checkOut)
        let restored = try JSONDecoder().decode(GuestCache.Snapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(restored.guests.first?.checkIn, guest.checkIn)
        XCTAssertEqual(restored.guests.first?.checkOut, guest.checkOut)
        XCTAssertEqual(restored.guests.first?.birthDate, guest.birthDate)
        XCTAssertEqual(restored.rangeStart, snapshot.rangeStart)
    }

    func testOldNumericCacheDatesRemainReadable() throws {
        let data = Data(#"{"Biografico":"Test","Identificador":"TEST","EstanciaId":"1","FechaEntrada":0}"#.utf8)
        let guest = try JSONDecoder().decode(Guest.self, from: data)
        XCTAssertEqual(guest.checkIn, Date(timeIntervalSinceReferenceDate: 0))
    }

    func testListDoesNotHideServerErrorsOrMalformedPayloads() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(GuestListResponse.self, from: Data(#"{"Error":"Rejected"}"#.utf8)))
        XCTAssertThrowsError(try JSONDecoder().decode(GuestListResponse.self, from: Data(#"{"unexpected":[]}"#.utf8)))
    }

    func testSMSIsConfiguredAndUnsupportedDialCodesAreRejected() {
        XCTAssertTrue(USSDSMSReporter.isAvailable)
        XCTAssertEqual(USSDSMSReporter.smsDestination, "7344")
        XCTAssertNil(USSDSMSReporter.dialURL(for: ""))
        XCTAssertNil(USSDSMSReporter.dialURL(for: "*123#"))
    }

    func testAntiForgeryInputAttributeOrderAndQuotes() throws {
        XCTAssertEqual(
            try AntiForgery.extract(from: "<input value='a&amp;b' type='hidden' name='__RequestVerificationToken'>"),
            "a&b")
    }
}

func fixtureGuest(id: String = "TEST-A", response: String = "OK") throws -> Guest {
    let object: [String: Any] = [
        "Biografico": "Test Guest", "Identificador": id,
        "EstanciaId": id, "FechaEntrada": "/Date(1772600400000)/",
        "FechaSalida": "/Date(1772773200000)/", "FechaNacimiento": "/Date(-315619200000)/",
        "Respuesta": response,
    ]
    return try JSONDecoder().decode(Guest.self, from: JSONSerialization.data(withJSONObject: object))
}

func fixturePerson(id: String = "TEST-A", birthDate: String? = "/Date(-315619200000)/") throws -> PersonaValidation {
    var object: [String: Any] = [
        "Nombre": "Test", "Apellido1": "Guest", "Biografico": "Test Guest",
        "Identificador": id, "Nacionalidad": "428", "Sexo": "F", "Respuesta": "OK",
    ]
    if let birthDate { object["FechaNac"] = birthDate }
    return try JSONDecoder().decode(PersonaValidation.self, from: JSONSerialization.data(withJSONObject: object))
}
