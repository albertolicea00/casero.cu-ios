# CASERO — iOS

Native iOS client for Cuban private lodging hosts (*arrendadores*) to report
their guests to the immigration authority.

Hosts are legally required to register every guest with immigration. Today that
means either dialing phone (USSD) codes and confirming by SMS, or using the
official web portal at `https://casero.rem.cu/` — a site that is only reachable
from inside Cuba and serves an untrusted TLS certificate. This app wraps both
channels behind a native, offline-friendly interface.

> **Unofficial project.** This is an independent client. It is not affiliated
> with, endorsed by, or maintained by CIDP-MININT or any government entity. It
> talks to the official portal using the host's own credentials, the same way a
> browser does.

## Features

- **Guest registration** through the two supported channels:
  - **USSD / SMS codes** — works without a data connection.
  - **Web portal API** — the app authenticates against `casero.rem.cu` and
    performs the same requests the browser makes.
- List active and registered guests, with companions.
- Manage communication channels (phones and emails) used by the portal.

## Tech stack

- **Language:** Swift
- **UI:** SwiftUI (to be confirmed as the project is scaffolded)
- **Dependencies:** Swift Package Manager
- **Networking:** the portal is ASP.NET MVC; the client must carry the
  anti-forgery token and session cookies (see [CLAUDE.md](CLAUDE.md)).

## Getting started

```bash
git clone <this-repo-url>
cd casero-cu-ios
open CaseroCU.xcodeproj   # or CaseroCU.xcworkspace once dependencies are added
```

Build and run from Xcode, or from the command line:

```bash
xcodebuild -scheme CaseroCU -destination 'platform=iOS Simulator,name=iPhone 15' build
```

Signing material (`*.p12`, `*.mobileprovision`, `*.p8`) is never committed —
see [.gitignore](.gitignore).

## The `casero.rem.cu` certificate

The portal serves a certificate that fails standard validation. The recommended
approach is **certificate pinning to the known server certificate** via a
`URLSessionDelegate` authentication challenge, not disabling App Transport
Security globally. See [CLAUDE.md](CLAUDE.md) for the reverse-engineered request
flow and the handling notes.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md). This repository uses
[Conventional Commits](https://www.conventionalcommits.org/).

## Related repositories

- `casero-cu-ios` — iOS client (this repository)
- `casero-cu-apk` — Android client

## License

[MIT](LICENSE) © 2026 Alberto Licea
