import Foundation

/// Discriminates the two `ValidarPersonaDiie` lookup modes seen in captured
/// traffic: `tipo=0` with a passport number, `tipo=2` with an underscore-joined
/// full name.
enum PersonaLookup: Int {
    case byPassport = 0
    case byName = 2
}

/// Thin client over the CASERO web portal. It behaves like a browser: cookies
/// (via `HTTPCookieStorage`) and the anti-forgery token are carried on every
/// request, and the portal's login redirect / `REDIRECT` sentinel are mapped to
/// `PortalError.sessionExpired`.
final class CaseroClient: NSObject, @unchecked Sendable {

    static let baseURL = URL(string: "https://casero.rem.cu/Plataforma/")!

    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 " +
        "(KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    private static let portalDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd/MM/yy"
        return formatter
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = 20
        config.httpAdditionalHeaders = ["User-Agent": Self.userAgent]
        return URLSession(configuration: config, delegate: self, delegateQueue: nil)
    }()

    // MARK: - Public API

    /// Authenticate. Throws `PortalError.invalidCredentials` when the portal rejects the login.
    func login(user: String, password: String) async throws {
        let token = try AntiForgery.extract(from: try await getHTML("Cuenta/IniciarSesion"))
        let body = formEncoded([
            ("__RequestVerificationToken", token),
            ("User", user),
            ("Password", password),
        ])
        let (_, response) = try await post("Cuenta/IniciarSesion", body: body)
        switch response.statusCode {
        case 300..<400: return // success: portal redirects to /Plataforma/
        case 200: throw PortalError.invalidCredentials
        default: throw PortalError.http(response.statusCode)
        }
    }

    /// Registered guests for a date range.
    func listGuests(from: Date, to: Date, pageSize: Int = 20, page: Int = 1) async throws -> [Guest] {
        let token = try AntiForgery.extract(from: try await getHTML("Huespedes/HuespedesRegistrados"))
        let body = formEncoded([
            ("fechaInicio", Self.portalDateFormatter.string(from: from)),
            ("fechaFin", Self.portalDateFormatter.string(from: to)),
            ("cantMaxRegistros", String(pageSize)),
            ("pagina", String(page)),
            ("__RequestVerificationToken", token),
        ])
        let text = try await postForJSON(
            "Huespedes/ListarHuespedes",
            body: body,
            referer: "Huespedes/HuespedesRegistrados",
        )
        return try JSONDecoder().decode(GuestListResponse.self, from: Data(text.utf8)).guests
    }

    func signOut() async {
        _ = try? await perform(request(for: "Cuenta/CerrarSesion", method: "GET"))
        HTTPCookieStorage.shared.cookies(for: Self.baseURL)?.forEach {
            HTTPCookieStorage.shared.deleteCookie($0)
        }
    }

    // MARK: - Companions

    /// Companions of a guest (Cuban nationals, identified by carné). Same paging
    /// contract as `ListarHuespedes` per CLAUDE.md, keyed by the guest's stay id.
    ///
    /// ASSUMPTION (unverified against live traffic): the request carries
    /// `estanciaId` alongside the paging fields, and the response envelope is
    /// shaped like `GuestListResponse` under a `ListaAcompannantes` key. Confirm
    /// against a real capture before relying on this in production.
    func listCompanions(estanciaId: String, pageSize: Int = 20, page: Int = 1) async throws -> [Guest] {
        let token = try AntiForgery.extract(from: try await getHTML("Huespedes/HuespedesRegistrados"))
        let body = formEncoded([
            ("estanciaId", estanciaId),
            ("cantMaxRegistros", String(pageSize)),
            ("pagina", String(page)),
            ("__RequestVerificationToken", token),
        ])
        let text = try await postForJSON(
            "Huespedes/ListarAcompannantes",
            body: body,
            referer: "Huespedes/HuespedesRegistrados",
        )
        return try JSONDecoder().decode(CompanionListResponse.self, from: Data(text.utf8)).companions
    }

    // MARK: - Registration

    /// Looks up a foreign guest in the DIIE registry.
    /// - Parameters:
    ///   - identificador: passport number (`tipo == .byPassport`) or an
    ///     underscore-joined full name (`tipo == .byName`), per captured traffic.
    func validatePersonaDiie(identificador: String, tipo: PersonaLookup) async throws -> PersonaValidation {
        try await validatePersona(
            path: "Huespedes/ValidarPersonaDiie",
            body: formEncodedWithToken([("identificador", identificador), ("tipo", String(tipo.rawValue))]),
        )
    }

    /// Looks up a Cuban companion by carné de identidad in the SUIN registry.
    func validatePersonaSuin(identificador: String) async throws -> PersonaValidation {
        try await validatePersona(
            path: "Huespedes/ValidarPersonaSuin",
            body: formEncodedWithToken([("identificador", identificador)]),
        )
    }

    private func validatePersona(path: String, body: (String) -> Data) async throws -> PersonaValidation {
        let token = try AntiForgery.extract(from: try await getHTML("Huespedes"))
        let text = try await postForJSON(path, body: body(token), referer: "Huespedes")
        return try JSONDecoder().decode(PersonaValidation.self, from: Data(text.utf8))
    }

    /// Registers one or more guests/companions in a single call (`|`-joined `personas`).
    func registerGuests(_ people: [GuestRegistration]) async throws -> [Guest] {
        guard !people.isEmpty else { return [] }
        let token = try AntiForgery.extract(from: try await getHTML("Huespedes"))
        let personas = people.map(\.wireFormat).joined(separator: "|")
        let body = formEncoded([
            ("personas", personas),
            ("__RequestVerificationToken", token),
        ])
        let text = try await postForJSON("Huespedes/RegistrarHuesped", body: body, referer: "Huespedes")
        return try Self.decodeGuestOrArray(Data(text.utf8))
    }

    // MARK: - Photos

    /// Foreign guest photo. Query parameters mirror the captured request exactly.
    func fetchForeignGuestPhoto(passport: String, name: String, nationalityCode: String, sex: String) async throws -> Data {
        var components = URLComponents(url: Self.baseURL.appending(path: "Huespedes/ObtenerFotoDiie"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "pasap", value: passport),
            URLQueryItem(name: "nomb", value: name),
            URLQueryItem(name: "apel1", value: ""),
            URLQueryItem(name: "apel2", value: ""),
            URLQueryItem(name: "ciud", value: nationalityCode),
            URLQueryItem(name: "sexo", value: sex),
        ]
        return try await fetchPhoto(at: components.url!)
    }

    /// Companion (Cuban national) photo, looked up by carné de identidad.
    func fetchCompanionPhoto(carne: String) async throws -> Data {
        var components = URLComponents(url: Self.baseURL.appending(path: "Huespedes/ObtenerFotoSUINPorCi"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "ci", value: carne)]
        return try await fetchPhoto(at: components.url!)
    }

    private func fetchPhoto(at url: URL) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        let (data, response) = try await perform(req)
        guard (200..<300).contains(response.statusCode) else {
            if (300..<400).contains(response.statusCode) { throw PortalError.sessionExpired }
            throw PortalError.http(response.statusCode)
        }
        return data
    }

    // MARK: - Requests

    private func getHTML(_ path: String) async throws -> String {
        let (data, response) = try await perform(request(for: path, method: "GET"))
        if (300..<400).contains(response.statusCode) { throw PortalError.sessionExpired }
        guard (200..<300).contains(response.statusCode) else { throw PortalError.http(response.statusCode) }
        return String(decoding: data, as: UTF8.self)
    }

    private func post(_ path: String, body: Data) async throws -> (Data, HTTPURLResponse) {
        var req = request(for: path, method: "POST")
        req.httpBody = body
        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        return try await perform(req)
    }

    private func postForJSON(_ path: String, body: Data, referer: String) async throws -> String {
        var req = request(for: path, method: "POST")
        req.httpBody = body
        req.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        req.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        req.setValue("application/json, text/javascript, */*; q=0.01", forHTTPHeaderField: "Accept")
        req.setValue(Self.baseURL.appending(path: referer).absoluteString, forHTTPHeaderField: "Referer")
        let (data, response) = try await perform(req)
        if (300..<400).contains(response.statusCode) { throw PortalError.sessionExpired }
        guard (200..<300).contains(response.statusCode) else { throw PortalError.http(response.statusCode) }
        let text = String(decoding: data, as: UTF8.self)
        if isRedirectSentinel(text) { throw PortalError.sessionExpired }
        return text
    }

    private func request(for path: String, method: String) -> URLRequest {
        var req = URLRequest(url: Self.baseURL.appending(path: path))
        req.httpMethod = method
        return req
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard CertificatePinner.isBundled else { throw PortalError.certificateNotBundled }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw PortalError.unreachable }
            return (data, http)
        } catch let error as PortalError {
            throw error
        } catch {
            throw PortalError.unreachable
        }
    }

    // MARK: - Helpers

    /// The portal returns `{ "message": "REDIRECT" }` on AJAX calls when the session is dead.
    private func isRedirectSentinel(_ text: String) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else {
            return false
        }
        return object["message"] as? String == "REDIRECT"
    }

    private func formEncoded(_ params: [(String, String)]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = params.map { key, value -> String in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    /// Builds a form body closure that appends the anti-forgery token once it's known.
    private func formEncodedWithToken(_ params: [(String, String)]) -> (String) -> Data {
        { token in self.formEncoded(params + [("__RequestVerificationToken", token)]) }
    }

    /// `RegistrarHuesped` returns a bare object for a single person and an array
    /// for multiple; normalize both to `[Guest]`.
    private static func decodeGuestOrArray(_ data: Data) throws -> [Guest] {
        if let array = try? JSONDecoder().decode([Guest].self, from: data) {
            return array
        }
        return [try JSONDecoder().decode(Guest.self, from: data)]
    }
}

/// Envelope for `Huespedes/ListarAcompannantes`. Field names for the request are
/// documented at the call site in `CaseroClient.listCompanions` as unverified.
private struct CompanionListResponse: Decodable {
    let error: String
    let page: Int
    let total: Int
    let companions: [Guest]

    private enum CodingKeys: String, CodingKey {
        case error = "Error"
        case page = "Pagina"
        case total = "Total"
        case companions = "ListaAcompannantes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = (try? container.decode(String.self, forKey: .error)) ?? ""
        page = (try? container.decode(Int.self, forKey: .page)) ?? 1
        total = (try? container.decode(Int.self, forKey: .total)) ?? 0
        companions = (try? container.decode([Guest].self, forKey: .companions)) ?? []
    }
}

// MARK: - TLS pinning & redirect handling

extension CaseroClient: URLSessionDelegate, URLSessionTaskDelegate {

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void,
    ) {
        let (disposition, credential) = CertificatePinner.evaluate(challenge)
        completionHandler(disposition, credential)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void,
    ) {
        // Do not follow redirects: the login 302 and the session-expiry 302 are signals.
        completionHandler(nil)
    }
}
