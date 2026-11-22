# 🏠 CASERO.cu — iOS
Native iOS client for Cuban lodging hosts to submit guest reports to the official portal. 🇨🇺

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/Platform-iOS-000000?logo=apple)](https://developer.apple.com/ios/)
[![Language: Swift](https://img.shields.io/badge/Language-Swift-F05138?logo=swift)](https://swift.org)
[![UI: SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![PRs: Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

[Mira la versión en español](README.es.md)

## ⚠️ Disclaimer

> [!WARNING]
> **Unofficial project.** Not affiliated with CIDP-MININT or any government entity. Talks to the official portal using the host's own credentials, the same way a browser does. We are not responsible for changes to `casero.rem.cu`, USSD/SMS codes, or any issues arising from using this software. Use at your own risk. Always verify guest registrations through official channels.

---

## ✨ Features

- Portal sign-in with scoped certificate pinning, cookies, and anti-forgery tokens.
- Guest lookups by passport, name, CI and temporary CI; batch registration with a
  review step, stay IDs in the result, PDF records (before, after and on failure)
  and retention of unconfirmed registrations. See the
  [registration contract](AGENTS.md#registration--confirmed).
- Guest lists with all pages, date selection, search, active/history filters, and
  offline access to retained data after reopening the app.
- Guest details, optional photo caching, and companion lookup with an official
  portal fallback.
- Read-only list of the host's registered phones and emails; adding or removing
  them opens the official portal page in Safari. No undocumented write endpoint
  is guessed. The portal profile (name, CI, username, address) is shown
  read-only; password changes go through the portal's profile page.
- In-app help: the official portal's help (with links to each portal page) and an
  offline summary of the Cubatramite reporting guide. Register and Guests explain
  what they do and flag that they are in beta.
- CSV/Excel and PDF exports from the complete cached date range.
- Device-only Keychain credentials (on by default), optional sign-in at launch and
  recovery of expired sessions behind Face ID/Touch ID/passcode, cache retention,
  and local data deletion on sign-out. See [SECURITY.md](SECURITY.md#saved-credentials-and-automatic-sign-in).
- English and Spanish UI and in-app user manual. The privacy policy, terms and
  EULA are on the [website](https://casero-cu.vercel.app/privacy.html).

SMS reporting is available without portal login: guest reports, Cuban companion
reports, and the separate confirmation SMS are prepared for **7344** with the
**HC** prefix. Phone association instructions use **18808**. iOS asks the user to
review and send each message; only the service's final registration code confirms
the report. See the [published procedure](https://cubatramite.com/reporte-a-inmigracion-del-registro-de-turistas-extranjeros-hospedados-en-viviendas-de-alquiler/)
and [SMS contract](AGENTS.md#sms-reporting-contract).

**Release status:** simulator tests cover synthetic data and mocked requests.
Live registration and the assumed companion request contract still need
verification from Cuba. See the [release checklist](ARCHITECTURE.md#release-checklist).

## 🛠 Tech Stack

| Layer | Choice |
|-------|--------|
| Language | Swift |
| UI | SwiftUI |
| Dependencies | Swift Package Manager |
| Networking | ASP.NET MVC portal (anti-forgery token + session cookies) |

## 🏗 Why Separate Native Apps? (iOS vs Android)

Rather than using a single cross-platform framework (e.g., Flutter or React Native), CASERO.cu maintains independent native codebases:

- **OS-level Permissions & Platform Freedoms:** Android allows deeper OS-level integrations (such as background tasks, custom telephony/USSD automation, and hardware APIs) that enable extending app functionality further over time.
- **iOS Sandbox & Capabilities:** iOS imposes stricter sandbox limits and restrictions (less API freedom), constraining features to what Apple explicitly permits.
- **Optimized Experience:** Developing natively for Swift/SwiftUI on iOS and Kotlin/Jetpack Compose on Android guarantees maximum performance, native UX, and proper platform-specific security (such as custom TLS pinning and background worker capabilities).

## 🚀 Getting Started

```bash
git clone https://github.com/albertolicea00/casero.cu-ios.git
cd casero.cu-ios
brew install xcodegen
xcodegen generate
open CaseroCu.xcodeproj
```

The Xcode project is generated and intentionally ignored by Git. The public portal
certificate, assets, localizations, and privacy manifest are included by
`project.yml`. Xcode and XcodeGen must be installed on macOS.

Build and test with an available simulator (choose its identifier using
`xcrun simctl list devices available`):

```bash
xcodebuild -scheme CaseroCu -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme CaseroCu -destination 'platform=iOS Simulator,id=<SIMULATOR_ID>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
xcrun swift-format lint --strict --recursive Sources Tests
```

Run **Actions → iOS checks → Run workflow** manually to generate the project
and run tests on an available iPhone simulator. Pushes and pull requests do not
start this workflow automatically. Tests never log in to the real portal or submit guest reports.

> 🔐 Signing material (`*.p12`, `*.mobileprovision`, `*.p8`) is never committed.

## 🔒 TLS Note

The portal serves a certificate that fails standard validation. The app uses **certificate pinning** via `URLSessionDelegate` — not global ATS disable. See [AGENTS.md](ARCHITECTURE.md#pinned-tls-certificate) for the certificate and how to renew it, and [AGENTS.md](AGENTS.md#portal-api-reference) for the reverse-engineered request flow.

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md), [SECURITY.md](SECURITY.md), and [Code of Conduct](CODE_OF_CONDUCT.md). Uses [Conventional Commits](https://www.conventionalcommits.org/).

### 🐛 Reporting Bugs

Found a bug? Open an issue in the repo where you found it:
- **iOS-specific bugs** → [file here](https://github.com/albertolicea00/casero.cu-ios/issues)
- **Android-specific bugs** → [file here](https://github.com/albertolicea00/casero.cu-apk/issues)
- **Core / cross-platform issues** (API changes, auth flow, etc.) → file in either repo, we'll track it across both

## 📦 Related

- [casero.cu-ios](https://github.com/albertolicea00/casero.cu-ios) — iOS client (this repo)
- [casero.cu-apk](https://github.com/albertolicea00/casero.cu-apk) — Android client
- [casero.cu-web](https://github.com/albertolicea00/casero.cu-web) — Web client

## 📄 License

[MIT](LICENSE) © 2026 Alberto Licea
