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

## Scope

This is an unofficial client that talks to `casero.rem.cu` using the host's own credentials. Vulnerabilities in the official portal itself should be reported to CIDP-MININT, not here.

