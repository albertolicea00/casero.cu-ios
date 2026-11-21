# Security Policy

## Reporting a Vulnerability

If you find a security issue in the iOS client, please open an issue **without** including credentials, tokens, or real guest data.

- **iOS-specific** → [open an issue](https://github.com/albertolicea00/casero.cu-ios/issues/new)
- **Core / cross-platform** (API auth, session handling, etc.) → file in either repo

Do **not** post credentials, session cookies, or real guest data in any issue.

## What to report

- Leaked credentials or tokens in the codebase
- Weak TLS / certificate handling
- Session fixation or replay issues
- Insecure storage of cookies or tokens
- **Changes to the portal** (`casero.rem.cu`) or **USSD/SMS codes** that break the app — these are critical, report them immediately
- Any other vulnerability that could expose a host's account or guest data

## Saved credentials and automatic sign-in

The portal account is an official government account. Every report made from it
is attributed to the host. The app's design follows from that: whoever can use the
saved credentials can view guests' personal data (passports, carnés, birth dates,
photos) and **register guests in the host's name**.

| Setting | Default | Why |
|---|---|---|
| Remember credentials | **On** | Without it the host types the password on every launch and every session expiry. Opt-out is acceptable because the storage below is device-bound and every use is gated. |
| Auto re-authenticate | **Off** | It signs in without typing anything. That is a deliberate opt-in, in line with privacy-by-default practice for personal data of third parties. |

How the credentials are protected:

- **Keychain, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.** Readable only while
  the device is unlocked and never restored to another device from a backup.
  Earlier builds used `AfterFirstUnlock` (readable while locked, included in
  backups); `KeychainStore.migrateAccessibility()` re-protects those items at
  launch.
- **Device owner check before every use.** `AppState.recoverSession()` calls
  `LAContext.evaluatePolicy(.deviceOwnerAuthentication)` (Face ID, Touch ID or the
  device passcode) before signing in with saved credentials. Without it, anyone
  holding an unlocked phone could open the app and act as the host. If the device
  has no passcode, or the user cancels, there is no silent sign-in and the sign-in
  banner is shown instead.
- **Two triggers, same gate:** at launch (`AppState.restoreSession()`) and when a
  request comes back as expired (`CaseroClient.authenticated`). Concurrent expiries
  share one recovery task, so the user sees one prompt.
- **Sign out deletes them.** `signOutCompletely()` clears the Keychain, so an
  explicit sign-out is never undone by the next launch.
- Credentials are saved only at a successful sign-in. Turning on "Remember
  credentials" while already signed in stores nothing until the next sign-in.

Considered and not done:

- *Keychain access control (`SecAccessControl` with `.userPresence`)* would make
  the Keychain itself enforce the check. It fails to save on devices without a
  passcode and prompts on every read, including the username prefill on the login
  form. The `LAContext` gate covers the same threat with less friction; revisit if
  the gate is ever bypassed in code.
- *Silent sign-in without a device owner check* was rejected for the reason at the
  top of this section.

Legal notes (not legal advice): Cuba's personal data protection law (Ley 149/2022)
applies to the guests' data this app handles; the requirements above follow
general privacy-by-default practice, not a reviewed reading of that law. This is an
unofficial client; the defaults do not change that, but they reduce what can go
wrong with a host's account and guests' data if a device is lost or shared.

Testing note: the iOS Simulator has no passcode by default, so silent sign-in
stays off there. Enroll Face ID (Features → Face ID → Enrolled) to exercise it.

## Scope

This is an unofficial client that talks to `casero.rem.cu` using the host's own credentials. Vulnerabilities in the official portal itself should be reported to CIDP-MININT, not here.

