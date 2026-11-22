import XCTest

@testable import CaseroCu

final class NetworkingTests: XCTestCase {
    private func client() -> CaseroClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PortalURLProtocol.self]
        return CaseroClient(configuration: configuration)
    }

    override func tearDown() {
        PortalURLProtocol.handler = nil
        super.tearDown()
    }

    func testGuestListLoadsEveryPage() async throws {
        let client = client()
        PortalURLProtocol.handler = { request in
            if request.httpMethod == "GET" { return (200, "text/html", tokenHTML) }
            let body = try formBody(request)
            let page = body.contains("pagina=1") ? 1 : 2
            let item = ["Biografico": "Test", "Identificador": "TEST-\(page)", "EstanciaId": "\(page)"]
            let payload: [String: Any] = ["Error": "", "Pagina": page, "Total": 2, "ListaHuespedes": [item]]
            return (
                200, "application/json",
                String(decoding: try JSONSerialization.data(withJSONObject: payload), as: UTF8.self)
            )
        }
        let guests = try await client.listGuests(from: Date(), to: Date(), pageSize: 1)
        XCTAssertEqual(guests.map(\.identificador), ["TEST-1", "TEST-2"])
    }

    func testSessionRecoveryRetriesWholeReadWithFreshToken() async throws {
        let client = client()
        let state = RequestState()
        client.recoverSession = {
            state.recovered = true
            return true
        }
        PortalURLProtocol.handler = { request in
            if request.httpMethod == "GET" {
                state.gets += 1
                return (200, "text/html", tokenHTML)
            }
            if !state.recovered { return (200, "application/json", #"{"message":"REDIRECT"}"#) }
            return (200, "application/json", #"{"Error":"","Pagina":1,"Total":0,"ListaHuespedes":[]}"#)
        }
        let guests = try await client.listGuests(from: Date(), to: Date())
        XCTAssertTrue(guests.isEmpty)
        XCTAssertEqual(state.gets, 2)
    }

    /// Captured from the portal when it refuses a registration: the app must show
    /// the portal's own message, not "unexpected response".
    func testRegistrationRejectionShowsPortalMessage() async throws {
        let client = client()
        PortalURLProtocol.handler = { request in
            if request.httpMethod == "GET" { return (200, "text/html", tokenHTML) }
            return (
                200, "application/json",
                #"{"success":false,"message":"No se ha registrado ningún huésped.","errors":{"nombre":"Error"}}"#
            )
        }
        let date = Date()
        let registration = GuestRegistration(
            firstName: "Test", lastName1: "Guest", lastName2: "",
            identificador: "TEST", nationalityCode: "428", sex: "F", birthDate: date,
            checkIn: date, checkOut: date, procedenciaCode: "428")
        do {
            _ = try await client.registerGuests([registration])
            XCTFail("A portal rejection must throw")
        } catch PortalError.rejected(let message) {
            XCTAssertEqual(message, "No se ha registrado ningún huésped.")
        } catch { XCTFail("Unexpected error: \(error)") }
    }

    /// Mirrors a browser capture of adding a companion from the active-guests page
    /// (synthetic person): CI lookup with `tipoDocumento=1`, then
    /// `RegistrarAcompannantes` with the stay ID and a 7-field entry whose name has spaces.
    func testAddCompanionMatchesPortal() async throws {
        let client = client()
        let state = RequestState()
        PortalURLProtocol.handler = { request in
            let path = request.url?.path ?? ""
            if request.httpMethod == "GET" {
                XCTAssertTrue(path.hasSuffix("Huespedes/HuespedesActivos"))
                return (200, "text/html", tokenHTML)
            }
            state.bodies.append(try formBody(request))
            if path.hasSuffix("ValidarPersonaSuin") {
                return (
                    200, "application/json",
                    #"[{"IdPersona":"x","Identificador":"00000000001","Nombre":"ANA","Nombre2":"MARIA","Apellido1":"LOPEZ","Apellido2":"DIAZ","Biografico":"ANA MARIA LOPEZ DIAZ","Sexo":"F","FechaNac":"\/Date(481611600000)\/","Nacionalidad":"247","DescNacionalidad":"CUBA"}]"#
                )
            }
            XCTAssertTrue(path.hasSuffix("RegistrarAcompannantes"))
            return (
                200, "application/json",
                #"[{"Biografico":"ANA MARIA LOPEZ DIAZ","Identificador":"00000000001","FechaEntrada":"\/Date(1795323600000)\/","FechaSalida":"\/Date(1795410000000)\/","FechaNacimiento":"\/Date(481611600000)\/","Sexo":"F","EstanciaId":"20000001","Id":"1","Respuesta":"OK"}]"#
            )
        }
        let found = try await client.validateCompanionForStay(identificador: "00000000001")
        let person = try XCTUnwrap(found.first)
        let entry = CompanionRegistration(
            fullName: person.fullName, identificador: person.identificador,
            nationalityCode: person.nationalityCode ?? "", sex: person.sex ?? "",
            birthDate: try XCTUnwrap(person.birthDate),
            checkIn: Date(timeIntervalSince1970: 1_795_323_600), checkOut: Date(timeIntervalSince1970: 1_795_410_000))
        XCTAssertEqual(entry.wireFormat, "ANA MARIA LOPEZ DIAZ,00000000001,247,F,06/04/85,22/11/26,23/11/26")
        let answer = try await client.addCompanions([entry], toStay: "20000001")
        XCTAssertEqual(answer.first?.stayId, "20000001")
        XCTAssertEqual(answer.first?.companionId, "1")
        XCTAssertEqual(answer.first?.response, "OK")
        XCTAssertTrue(state.bodies[0].hasPrefix("identificador=00000000001&tipoDocumento=1&"))
        XCTAssertTrue(state.bodies[1].hasPrefix("estanciaId=20000001&personas=ANA%20MARIA%20LOPEZ%20DIAZ%2C00000000001%2C247%2CF%2C06%2F04%2F85%2C22%2F11%2F26%2C23%2F11%2F26&"))
    }

    func testUncertainRegistrationFailureIsNeverAutomaticallyRetried() async throws {
        let client = client()
        let state = RequestState()
        client.recoverSession = {
            state.recovered = true
            return true
        }
        PortalURLProtocol.handler = { request in
            if request.httpMethod == "GET" { return (200, "text/html", tokenHTML) }
            state.gets += 1
            throw URLError(.timedOut)
        }
        let date = Date()
        let registration = GuestRegistration(
            firstName: "Test", lastName1: "Guest", lastName2: "",
            identificador: "TEST", nationalityCode: "428", sex: "F", birthDate: date,
            checkIn: date, checkOut: date, procedenciaCode: "428")
        do {
            _ = try await client.registerGuests([registration])
            XCTFail("A timeout must remain an uncertain failure")
        } catch PortalError.registrationUncertain {} catch { XCTFail("Unexpected error: \(error)") }
        XCTAssertEqual(state.gets, 1)
        XCTAssertFalse(state.recovered)
    }

    func testPublicCertificateIsIncludedInGeneratedApp() {
        XCTAssertTrue(CertificatePinner.isBundled)
    }

    func testRepeatedPageFailsInsteadOfExportingIncompleteData() async throws {
        let client = client()
        PortalURLProtocol.handler = { request in
            if request.httpMethod == "GET" { return (200, "text/html", tokenHTML) }
            return (
                200, "application/json",
                #"{"Error":"","Total":3,"ListaHuespedes":[{"Biografico":"Test","Identificador":"TEST","EstanciaId":"1"}]}"#
            )
        }
        do {
            _ = try await client.listGuests(from: Date(), to: Date(), pageSize: 1)
            XCTFail("Repeated pages must not be accepted")
        } catch PortalError.invalidResponse {} catch { XCTFail("Unexpected error: \(error)") }
    }
}

private let tokenHTML = "<input name=\"__RequestVerificationToken\" value=\"fixture-token\">"

private final class RequestState: @unchecked Sendable {
    var recovered = false
    var gets = 0
    var bodies: [String] = []
}

private func formBody(_ request: URLRequest) throws -> String {
    if let data = request.httpBody { return String(decoding: data, as: UTF8.self) }
    guard let stream = request.httpBodyStream else { return "" }
    stream.open()
    defer { stream.close() }
    var data = Data()
    var buffer = [UInt8](repeating: 0, count: 4096)
    while stream.hasBytesAvailable {
        let count = stream.read(&buffer, maxLength: buffer.count)
        if count <= 0 { break }
        data.append(buffer, count: count)
    }
    return String(decoding: data, as: UTF8.self)
}

private final class PortalURLProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((URLRequest) throws -> (Int, String, String))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let result = try Self.handler!(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: result.0, httpVersion: nil,
                headerFields: ["Content-Type": result.1])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(result.2.utf8))
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
