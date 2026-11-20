# Release verification

## Implemented locally

- Date-preserving guest cache, including legacy numeric cache dates and valid
  birth dates before 1970.
- Server error propagation, complete guest pagination, duplicate-page detection,
  date range selection, and active/history filtering.
- Registration validation with no invented birth date, duplicate prevention,
  and preservation of unconfirmed people after partial or uncertain results.
- Session recovery retries only explicit expiry, with fresh form tokens. Network
  timeouts never automatically resend a registration.
- Offline access after reopening the app, cache retention, optional photo storage,
  protected local files, and cache invalidation after clearing or signing out.
- Photos and guest details, companion pagination, and an official portal fallback.
- Communication-channel management through the actual portal form in an
  ephemeral, pinned, host-restricted WKWebView.
- Whole-day CSV/PDF exports, CSV formula escaping, wrapped PDF text, optional
  photos, and removal of temporary export files after sharing.
- Guest, companion, and confirmation SMS messages to 7344 using the HC prefix,
  phone association instructions through 18808, validation, message previews,
  and explicit distinction between sending an SMS and receiving a registration.
- Spanish and English UI, credential autofill, local privacy information, app
  assets, iPad orientations, generated project resources, tests, and CI workflow.

The tests use fabricated fixtures and URLProtocol stubs. Passing them establishes
local behavior, not compatibility with the current live portal.

## Local verification on November 19, 2026

- 29 simulator tests passed with no failures.
- An unsigned Release archive for a physical iOS device was generated successfully.
- Strict Swift formatting, whitespace checks, and resource property-list validation passed.
- A credential-free connection attempt to the live portal ended during TLS
  negotiation with `UNEXPECTED_EOF_WHILE_READING`. No authenticated request or
  guest report was sent, and live compatibility was not established.
- Visual interaction with Simulator was not authorized in this environment;
  visual and physical-device checks remain open.

## External requirements before distribution

1. **Live portal acceptance from Cuba:** verify login/logout, rejection of bad
   credentials, session expiry/recovery, a real authorized registration, active
   and historical lists, paging, photo retrieval, and the embedded phone/email
   form. Confirm the result in the official portal. Never store real data in
   fixtures, screenshots, source files, CI logs, or issue reports.
2. **Companion contract:** confirm `estanciaId` and `ListaAcompannantes` against
   anonymized traffic. These names were assumptions in the existing client.
   Native lookup surfaces errors and offers the real portal as a fallback.
3. **Registration contract:** verify names, origin/nationality codes, dates,
   per-person `Respuesta`, and mixed accepted/rejected responses against actual
   portal traffic. The client does not assume that an ambiguous result succeeded.
4. **Live TLS pin:** confirm the bundled fingerprint against the real server.
   The bundled certificate expires May 12, 2027. Prepare a reviewed rotation
   before the server changes certificates.
5. **Carrier acceptance:** the supplied reference pages document SMS to 7344,
   HC-prefixed requests, and confirmation. The app implements that protocol.
   Validate a complete authorized exchange on a registered physical phone,
   including the final registration code. No separate USSD dial string was
   supplied, so none is invented.
6. **Physical iPhone:** validate guest flows, poor connectivity, device locking,
   VoiceOver, largest text sizes, dark mode, and exported files. Simulator tests
   cannot establish carrier behavior or real portal reachability.
7. **Distribution:** configure the owner's Apple Developer team and signing
   outside Git, choose TestFlight/App Store distribution, supply store metadata,
   a hosted privacy policy and support URL, and review portal data disclosures.
   No upload or publication is performed by this change.

## Repeatable checks

```bash
xcodegen generate
xcodebuild -scheme CaseroCu -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme CaseroCu -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcrun swift-format lint --strict --recursive Sources Tests
git diff --check
```

The generated Xcode project is ignored. `project.yml`, the public server
certificate, localizations, privacy manifest, and tests are the reproducible
inputs. The CI workflow uses only `workflow_dispatch`. After pushing these changes,
start it manually with **Actions → iOS checks → Run workflow**.
