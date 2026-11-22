# ARCHITECTURE.md — CASERO iOS

How the app is built and released. The portal API it talks to, the SMS contract,
findings and open questions are in [AGENTS.md](AGENTS.md); conventions and
commands too. Update this file in the same commit as any change to the flows
described here.

Contents:

1. [Repository map](#repository-map)
2. [How the app uses the portal](#how-the-app-uses-the-portal)
3. [Saved credentials](#saved-credentials)
4. [Pinned TLS certificate](#pinned-tls-certificate)
5. [Release checklist](#release-checklist)

---

## Repository map

| Path | What lives there |
|---|---|
| `Sources/App/CaseroCuApp.swift` | `AppState` (session, saved-credential sign-in, banners), tab layout, `AuthGate` |
| `Sources/Networking/CaseroClient.swift` | Every portal request, token handling, session recovery, TLS pinning |
| `Sources/Networking/PortalError.swift` | All portal errors and their user-facing text |
| `Sources/Networking/PortalServing.swift` | Protocol the view models use, so tests can stub the portal |
| `Sources/Models/` | `Guest` (lists, registration answers), `PersonaValidation` + `GuestRegistration` (lookups, `personas=` wire format), `DotNetDate`, `PortalDates` (Cuba calendar/time zone) |
| `Sources/Features/Register/` | Lookup, result sheet, queue, review sheet, results, PDFs |
| `Sources/Features/Guests/` | Guest list, detail, companions, photos, `GuestAvatar`, `GuestNameTooltip`, `NationalityFlag`, `GuestStayText` |
| `Sources/Features/SMS/` | SMS report composer (7344) |
| `Sources/Features/Settings/`, `Login/` | Settings, exports, sign-in |
| `Sources/Persistence/` | `AppSettings`, `KeychainStore`, `GuestCache`, `PhotoCache` |
| `Sources/Support/` | `ExportService` (CSV/PDF), `GuestPhotoService`, `InputCard`, `PrimaryActionButtonStyle`, `ShareSheet`, `ConnectivityMonitor` |
| `Tests/` | Unit tests with fabricated fixtures and `URLProtocol` stubs |
| `.ignore/` | Local, git-ignored browser captures. Contain live cookies and real data. Never commit, never quote in issues |

---

## How the app uses the portal

### Session

- `CaseroClient.authenticated` wraps every call. On `sessionExpired` it asks
  `AppState.recoverSession()` (saved credentials + device owner check, see
  [Saved credentials](#saved-credentials)) and retries **once** with a fresh
  token. If recovery fails, `AppState.reportSessionExpired()` shows the orange
  "session expired" banner.
- Banners above the tabs (`MainTabView`): orange *session expired* (all tabs),
  red *no internet* (all tabs), yellow *sign in to the app session* (Register,
  Guests and Settings, when signed out). Tapping a sign-in banner opens
  `LoginView` as a sheet.
- At launch `AppState.restoreSession()` signs in silently when both "Remember
  credentials" and "Auto re-authenticate" are on.

### Guests tab

- **Active** stays (checked in, not yet past check-out) are grouped by departure:
  "Leaves today", "Leaves tomorrow", "Leaves in N days", with the departure date
  on the right of the header; soonest departure first. Days are counted in Cuba
  time (`GuestsViewModel.daysUntilCheckOut`). The sort menu is hidden here.
- **History** is grouped by check-in month and follows the sort menu.
- **Add companion** (guest detail, only when `Guest.isActive()` and not a
  companion): `AddCompanionView` looks up a CI (`validateCompanionForStay`),
  shows the person card, takes stay dates (check-in from today, never before the
  guest's check-in nor more than 7 days back; check-out defaults to the guest's),
  asks for confirmation, calls `addCompanions(_:toStay:)` and shows the stay ID
  and companion ID. On success the companion list reloads. Lost answers and
  refusals behave as in registration (`postRegistration` in `CaseroClient`).
- **Update check-out** (`UpdateCheckOutView`, `CaseroClient.updateCheckOut`):
  on the stay card of an active guest, and on each active companion card that
  has a portal `Id`. The date picker starts at the person's check-in day;
  current and new dates and nights are shown, the host confirms, and the
  portal's message is displayed. Afterwards the guest screen shows the new date
  and Guests reloads (`AppState.guestsDidChange()`); for a companion the
  companion list reloads.
- The side scrubber shows the current group's title while dragging.

### Registration flow (Register tab)

1. **Lookup.** A segmented selector: Passport · ID card (CI) · Name · Temp. ID.
   Below it the full title, the fields (three for name: first name only, first
   and second surname), the portal's help text, and a "Look up" button. Lookup
   errors show under the button; the portal message is shown verbatim, and name
   lookups add "try without the second given name".
2. **Result sheet** (`LookupResultSheet`). Every result opens it. One match is
   already active; several are listed as cards with photo and birth date and the
   host taps the right one. Below, apart: check-in/check-out (check-in limited to
   7 days back), nights, validation, and "Add to registration".
3. **Queue** ("Ready to register"). One `RegistrationCard` per person: photo,
   one-line name (tap for the full name), Passport/ID, origin, birth date, stay
   range and nights, and a trash button that asks for confirmation.
4. **Review sheet** (`SubmitSummarySheet`). The same cards, a warning that the app
   cannot undo a registration, "Register N people", and "Save PDF".
5. **Result** ("Last result"). One `RegistrationResultCard` per person: ✅/❌,
   person card, **stay ID** (copyable), stay range, and "Save PDF". On success
   `AppState.guestsDidChange()` makes Guests reload.

Rules:

- **Companion = found by CI** (`GuestRegistration.isCompanion`), never derived
  from nationality: Cubans living abroad are found by passport and are main
  guests. A queue of companions alone shows a yellow warning but **is still
  sent**; the portal decides and its answer is shown.
- **Lost answer.** If the registration POST was sent but no answer came back
  (connection drop, timeout, HTTP 5xx), the client throws
  `PortalError.registrationUncertain`. Nothing is retried, the queue is kept,
  each card is marked "sent without confirmation", and the host is told to check
  Guests or the portal before re-sending. Session recovery only retries after an
  explicit `REDIRECT`, which means nothing was registered.
- **Refusal** (`success: false`) → `PortalError.rejected(message)`; the queue is
  kept; under the error the app suggests SMS or the nearest immigration office
  and offers a PDF.
- **PDFs** (`ExportService.registrationPDF`, Cuba time, `dd/MM/yyyy`):
  *prepared* (review sheet), *submitted* (status + stay IDs), *failed* (error,
  "may already be registered" when uncertain, how to finish the report). None
  of them is proof of registration; only portal stay IDs are. Files are written
  to the temp folder with complete file protection and handed to the share sheet.
- The result's name comes from `Biografico`, with `*` turned into spaces.

---

## Saved credentials

Read [SECURITY.md](SECURITY.md#saved-credentials-and-automatic-sign-in) before
touching `KeychainStore`, `AppState.recoverSession()` or the session settings.
Invariants:

- Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.
- Every sign-in with saved credentials passes the `LAContext`
  `.deviceOwnerAuthentication` check first; no passcode means no silent sign-in.
- "Remember credentials" defaults on; "Auto re-authenticate" defaults off.
- Sign-out clears the Keychain.

---

## Pinned TLS certificate

**What it is.** `Resources/casero_rem_cu.cer` is the portal's **public** server
certificate in DER format. It contains no private key and is not Apple signing
material, so it is committed on purpose (`.gitignore` ignores every `*.cer`
except this one).

| Field | Value |
|---|---|
| Subject | `C=CU, O=REM, OU=CSIC, CN=*.rem.cu` (wildcard, SAN `*.rem.cu`) |
| Issuer | `C=CU, O=REM, OU=CSIC, CN=CSIC P-Services CA` (private CA, not trusted by iOS) |
| Valid | 2026-05-12 → **2027-05-12** (04:00 UTC) |
| SHA-256 | `CD:18:11:14:6B:37:3D:17:B0:0C:CB:44:B6:22:FA:EA:E1:F9:0A:59:46:98:5A:3E:1A:55:42:C6:BD:71:56:E2` |

**Why it is needed.** iOS does not trust the issuing CA, so a normal HTTPS request
to the portal fails. Instead of disabling App Transport Security, the app trusts
exactly this certificate for `casero.rem.cu` and nothing else.

**How the app uses it** (`Sources/Networking/CertificatePinner.swift`):

- Only challenges for host `casero.rem.cu` are touched; every other host gets the
  default system handling.
- The server's **leaf certificate bytes must equal the bundled file**. Then the
  leaf is set as the only trust anchor and evaluated with the SSL policy, so
  expiry dates, server-auth usage and the hostname are still checked.
- If the file is missing from the bundle, every portal request fails with
  `PortalError.certificateNotBundled` (fail closed). The test
  `testPublicCertificateIsIncludedInGeneratedApp` guards the bundling.
- `Info.plist` has a scoped ATS exception for `casero.rem.cu` (minimum TLS 1.2,
  no forward secrecy required). No global ATS relaxation.

**What breaks and when.** Because the pin is the exact leaf, the app stops
connecting the moment the portal serves a different certificate: at expiry
(2027-05-12) or earlier if the portal renews or re-keys. Users then need an app
update. Plan the rotation **before** the expiry date.

**How to obtain or renew it** (only reachable from a network in Cuba):

```bash
openssl s_client -connect casero.rem.cu:443 -servername casero.rem.cu </dev/null \
  | openssl x509 -outform der -out /tmp/casero_rem_cu.cer
openssl x509 -inform DER -in /tmp/casero_rem_cu.cer -noout -subject -issuer -dates -fingerprint -sha256
```

1. Fetch it from a trusted connection inside Cuba.
2. **Verify the fingerprint through a second channel** (another network or
   device, or the browser's certificate viewer on the portal). A single fetch on
   a hostile network could hand you an attacker's certificate.
3. Replace `Resources/casero_rem_cu.cer`, update the table above, run
   `xcodegen generate`, the tests, and one real sign-in.
4. Ship the update before the old certificate stops being served.

Never replace the pin automatically after a failed connection, and never fall back
to trusting any certificate.

**Improvement to consider.** Accept a small set of pins (current + next) or pin
the public key (SPKI) instead of the whole leaf, so a renewal with the same key,
or a prepared next certificate, does not break installed apps. Not implemented.

A copy named `casero_rem_cu.cer` may exist at the repository root; it is
git-ignored and unused. Only the one in `Resources/` is bundled.

---

## Release checklist

Simulator tests use fabricated fixtures and `URLProtocol` stubs. Passing them
proves local behaviour, not compatibility with the live portal.

Before each release:

1. **Checks:** `xcodegen generate`, build, tests, `swift-format lint --strict`,
   `git diff --check` (see [AGENTS.md](AGENTS.md#commands)). The CI workflow
   (`.github/workflows/ios.yml`) runs only on manual dispatch:
   **Actions → iOS checks → Run workflow**.
2. **Live portal from Cuba:** sign-in, bad credentials, session expiry and
   recovery, guest lists and paging, photos, and one real authorized
   registration confirmed in the official portal (first done 2026-11-22, issue #2).
3. **Companion list contract:** confirm `ListarAcompannantes` against real traffic
   (still assumed).
4. **TLS pin:** confirm the live certificate still matches the bundled one; the
   current one expires **2027-05-12** (see [Pinned TLS certificate](#pinned-tls-certificate)).
5. **SMS:** a complete authorized exchange on the host's registered phone,
   including the final registration code.
6. **Physical iPhone:** poor connectivity, device lock, Face ID / passcode,
   VoiceOver, largest text sizes, dark mode, exported PDFs.
7. **Distribution:** Apple Developer team and signing kept outside Git,
   TestFlight/App Store choice, store metadata, hosted privacy policy and support
   URL, review of the portal data disclosures (`Resources/PrivacyInfo.xcprivacy`
   declares only app-local UserDefaults and file timestamp usage).

Never store real data in fixtures, screenshots, source files, CI logs or issues.

### Verification log

- **2026-11-22** — Registration sent from the app on a device was accepted by
  the live portal and showed the stay IDs (issue #2, closed).
- **2026-11-21** — 33 simulator tests, 29 pass; the 4 failures are the stale
  `SMSReportingTests` (see [known issues](AGENTS.md#open-questions-and-known-issues)). `swift-format lint --strict` fails on
  formatting only. Registration wire format and answers confirmed against web
  captures; no registration sent from the app yet.
- **2026-11-19** — 29 tests passed. Unsigned Release archive for a device built.
  Strict formatting, whitespace and plist checks passed. A credential-free TLS
  attempt to the live portal ended with `UNEXPECTED_EOF_WHILE_READING`; no
  authenticated request was sent. Visual and physical-device checks not done.
