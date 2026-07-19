# 🏠 CASERO.cu — iOS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: iOS](https://img.shields.io/badge/Platform-iOS-000000?logo=apple)](https://developer.apple.com/ios/)
[![Language: Swift](https://img.shields.io/badge/Language-Swift-F05138?logo=swift)](https://swift.org)
[![UI: SwiftUI](https://img.shields.io/badge/UI-SwiftUI-007AFF?logo=swift)](https://developer.apple.com/xcode/swiftui/)
[![PRs: Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](CONTRIBUTING.md)

[Mira la versión en español](README.es.md)

Native iOS client for Cuban lodging hosts to submit guest reports to the official portal. 🇨🇺

> ⚠️ **Unofficial project.** Not affiliated with CIDP-MININT or any government entity. Talks to the official portal using the host's own credentials, the same way a browser does.
>
> 🛡️ **Disclaimer:** We are not responsible for changes to `casero.rem.cu`, USSD/SMS codes, or any issues arising from using this software. Use at your own risk. Always verify guest registrations through official channels.

---

## ✨ Features

- 📋 **Guest registration** via two channels:
  - 📞 **USSD / SMS codes** — works offline, no data connection needed
  - 🌐 **Web portal API** — authenticates against `casero.rem.cu` and mirrors browser requests
- 👥 List active & registered guests with companions
- 📱 Manage communication channels (phones & emails)

## 🛠 Tech Stack

| Layer | Choice |
|-------|--------|
| Language | Swift |
| UI | SwiftUI |
| Dependencies | Swift Package Manager |
| Networking | ASP.NET MVC portal (anti-forgery token + session cookies) |

## 🚀 Getting Started

```bash
git clone https://github.com/albertolicea00/casero.cu-ios.git
cd casero.cu-ios
open CaseroCU.xcodeproj
```

Build from CLI:

```bash
xcodebuild -scheme CaseroCU -destination 'platform=iOS Simulator,name=iPhone 15' build
```

> 🔐 Signing material (`*.p12`, `*.mobileprovision`, `*.p8`) is never committed.

## 🔒 TLS Note

The portal serves a certificate that fails standard validation. The app uses **certificate pinning** via `URLSessionDelegate` — not global ATS disable. See [CLAUDE.md](CLAUDE.md) for the reverse-engineered request flow.

## 🔄 Reporting code source of truth

USSD/SMS codes across my apps are centralized in **[MyUSSDCodes-collection](https://github.com/albertolicea00/MyUSSDCodes-collection)** (the single source of truth). CASERO's guest-report code is **not finalized yet** — `USSDSMSReporter` still ships `smsDestination` / `reportBody` placeholders.

A weekly GitHub Action ([`ussd-sync-check`](.github/workflows/ussd-sync-check.yml)) watches the canonical [`casero-report`](https://github.com/albertolicea00/MyUSSDCodes-collection/blob/main/codes/casero-report.json) collection. It is **expected to stay red** until the real reporting code is published there (its `placeholder` tag removed) — that red is the reminder. Once it lands, wire the real dial string into `USSDSMSReporter` and close the tracking issue.

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

## 📄 License

[MIT](LICENSE) © 2026 Alberto Licea