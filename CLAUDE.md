# CLAUDE.md — CASERO iOS

Guidance for Claude Code (and humans) working in this repository.

## What this is

Native iOS client that lets Cuban lodging hosts report guests to immigration. It
is an **unofficial** client for the official portal at `https://casero.rem.cu/`
and for the USSD/SMS reporting codes. Not affiliated with CIDP-MININT.

Sibling repository: `casero-cu-apk` (this is **not** a monorepo — the two
platforms live in separate repositories).

## Conventions

- **All code, comments, identifiers and docs are written in English.**
- **Commits** follow [Conventional Commits](https://www.conventionalcommits.org/)
  (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`, `test:`, `build:`, `ci:`).
- Do **not** add AI/tool attribution or co-author trailers to commits.
- Language: Swift. UI: SwiftUI (unless decided otherwise). Deps: Swift Package
  Manager.
- Never commit signing material, tokens, credentials, or real guest data.

## Common commands

```bash
# Build for the simulator
xcodebuild -scheme CaseroCu -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run unit tests
xcodebuild -scheme CaseroCu -destination 'platform=iOS Simulator,name=iPhone 15' test

# Lint / format (if wired in)
swiftlint
swift-format lint --recursive Sources
```

## Portal API contract (reverse-engineered)

The backend is an **ASP.NET MVC** app served under the base path `/Plataforma/`.
The client must behave like a browser: keep cookies and echo the anti-forgery
token on every POST. Use a shared `URLSession` with an `HTTPCookieStorage` so
cookies persist across requests.

Base URL: `https://casero.rem.cu/Plataforma/`

### Authentication

1. `GET /Cuenta/IniciarSesion` — returns the login page. Two things matter:
   - a hidden input `__RequestVerificationToken` (anti-forgery **form** token);
   - a cookie `__RequestVerificationToken_L1BsYXRhZm9ybWE1` (anti-forgery
     **cookie** token). Both must be sent together on the login POST.
2. `POST /Cuenta/IniciarSesion` — `application/x-www-form-urlencoded` body:
   - `__RequestVerificationToken=<form token>`
   - `User=<username>`
   - `Password=<password>`
   On success the server sets `ASP.NET_SessionId` and `__ca_` cookies. All
   later requests must carry the anti-forgery cookie + `ASP.NET_SessionId` +
   `__ca_`.
3. `GET /Cuenta/CerrarSesion` — logout.
4. `GET /Cuenta/Perfil` — profile page.

Password rule enforced by the portal (mirror it client-side for early
validation): 8–100 chars, regex
`^(?=.*[A-Z])(?=.*\W)(?=.*[0-9])(?=.*[a-z]).*$`.

### Guests

- `GET /Huespedes` — register guests page.
- `GET /Huespedes/HuespedesActivos` — active guests page.
- `GET /Huespedes/HuespedesRegistrados` — registered guests page.
- `POST /Huespedes/ListarHuespedes` — JSON list. Form body:
  - `fechaInicio=DD/MM/YY`
  - `fechaFin=DD/MM/YY`
  - `cantMaxRegistros=<page size>`
  - `pagina=<1-based page>`
  - `__RequestVerificationToken=<token from page>`

  Response shape:

  ```json
  {
    "Error": "",
    "Pagina": 1,
    "Total": 12,
    "ListaHuespedes": [
      {
        "Biografico": "<full name>",
        "Identificador": "<passport>",
        "FechaEntrada": "/Date(1772600400000)/",
        "FechaSalida": "/Date(1772773200000)/",
        "FechaNacimiento": "/Date(-62135578800000)/",
        "Nacionalidad": "428",
        "DescNacionalidad": "ESPANA",
        "Procedencia": null,
        "Sexo": null,
        "EstanciaId": "20891158",
        "Respuesta": null
      }
    ]
  }
  ```

- `POST /Huespedes/ListarAcompannantes` — companions of a guest (same paging
  contract; companions are Cuban nationals identified by *carné de identidad*).
- `GET /Huespedes/ObtenerFotoDiie?pasap=<passport>&nomb=<name>&apel1=&apel2=&ciud=<nationality>&sexo=<sex>`
  — foreign guest photo.
- `GET /Huespedes/ObtenerFotoSUINPorCi?ci=<carné>` — companion photo.

### Communication channels (`Vías de Comunicación`)

- `GET /ViasComunicacion` — page.
- `POST` to the "list channels" action — returns the host's registered phones
  and emails.
- `POST` to the "modify channels" action — body `vias=<comma-separated>` plus
  the anti-forgery token. Phones are stored as `+535XXXXXXX` (a Cuban mobile is
  7 digits after the `535` prefix); emails are validated client-side.

### Important behaviors

- **Session expiry sentinel:** JSON endpoints return `{ "message": "REDIRECT" }`
  when the session is dead. The client must detect this and route back to login
  instead of parsing it as data.
- **.NET date format:** timestamps arrive as `/Date(<epoch-ms>)/`. Parse the
  integer between the parentheses as UTC milliseconds. The value
  `-62135578800000` is .NET `DateTime.MinValue` and means "no date".
- **TLS:** the server certificate fails standard chain validation. Prefer
  **certificate pinning** to the known `casero.rem.cu` certificate in a
  `URLSessionDelegate.urlSession(_:didReceive:completionHandler:)` challenge
  over disabling App Transport Security globally. Document and isolate this so it
  never leaks into other network calls.
- **Reachability:** the portal is only reachable from inside Cuba. Expect
  connection failures elsewhere and surface them clearly; fall back to USSD/SMS.

## SMS reporting contract

The supplied reference material documents SMS, not a USSD dial string:

- Destination: `7344`.
- Associate the host's phone first by calling `18808` and waiting for confirmation.
- Foreign guest request: `HC<passport> <stay days>`.
- Cuban companion request: `HC<main guest passport> <companion identity number> <stay days>`.
  Confirm the main guest's registration before reporting companions.
- The first reply supplies guest data and a confirmation code. After reviewing
  that data, send `HC<confirmation code>` to the same destination.
- Only the final registration code establishes that the service registered the
  report. Sending an SMS alone is not registration success.
- Each person has a separate exchange. Confirmation requests expire after six
  hours according to the published instructions.
- iOS presents `MFMessageComposeViewController`; the user sends each message.
  Never auto-send, read SMS inbox contents, or invent a USSD command.

References: the SMS procedure section of the sibling web project's `index.html`
and [the supplied published guide](https://cubatramite.com/reporte-a-inmigracion-del-registro-de-turistas-extranjeros-hospedados-en-viviendas-de-alquiler/).
These describe the format; physical carrier acceptance still requires a device
with the host's registered number.

## Saved credentials

Read [SECURITY.md](SECURITY.md#saved-credentials-and-automatic-sign-in) before
touching `KeychainStore`, `AppState.recoverSession()` or the session settings.
Keep these invariants:

- Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Every sign-in with saved credentials passes the `LAContext`
  `.deviceOwnerAuthentication` check first; no passcode means no silent sign-in.
- "Remember credentials" defaults on; "Auto re-authenticate" defaults off.
- Sign-out clears the Keychain.

## What not to do

- Do not hardcode credentials, tokens, cookies, or real guest data anywhere.
- Do not weaken TLS validation for hosts other than `casero.rem.cu`.
- Do not sign in with saved credentials without the device owner check.
- Do not introduce a monorepo layout — Android stays in its own repository.
