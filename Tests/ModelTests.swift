import XCTest

@testable import CaseroCu

final class ModelTests: XCTestCase {
    /// Mirrors a browser capture of `RegistrarHuesped` (synthetic names/IDs, real
    /// shape): four `*`-joined name parts, `**` when there is no second name.
    func testRegistrationWireFormatMatchesPortal() {
        func date(_ ms: Double) -> Date { Date(timeIntervalSince1970: ms / 1000) }
        let checkIn = date(1_794_978_000_000)
        let checkOut = date(1_795_237_200_000)
        let guest = GuestRegistration(
            firstName: "TESTA", lastName1: "UNO", lastName2: "DOS", identificador: "X0000001",
            nationalityCode: "201", sex: "M", birthDate: date(122_533_200_000),
            checkIn: checkIn, checkOut: checkOut, procedenciaCode: "201")
        let companion = GuestRegistration(
            firstName: "TESTB", middleName: "MEDIO", lastName1: "TRES", lastName2: "CUATRO",
            identificador: "00000000001", nationalityCode: "247", sex: "F", birthDate: date(481_611_600_000),
            checkIn: checkIn, checkOut: checkOut, procedenciaCode: "247")
        XCTAssertEqual(
            [guest, companion].map(\.wireFormat).joined(separator: "|"),
            "TESTA**UNO*DOS,X0000001,201,M,19/11/73,18/11/26,21/11/26,201|"
                + "TESTB*MEDIO*TRES*CUATRO,00000000001,247,F,06/04/85,18/11/26,21/11/26,247")
    }

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
