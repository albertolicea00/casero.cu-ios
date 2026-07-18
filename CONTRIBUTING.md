# Contributing to CASERO iOS

Thanks for taking the time to contribute. This document explains how to propose
changes to the iOS client.

## Ground rules

- Everything — code, comments, identifiers, documentation — is written in
  **English**.
- Be respectful. All participation is governed by our
  [Code of Conduct](CODE_OF_CONDUCT.md).
- Never commit credentials, signing certificates, provisioning profiles, API
  tokens, or real guest data. If you ever paste a sample request, strip the
  username, password, cookies and any personal data first.

## Getting set up

1. Fork the repo on GitHub
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/casero.cu-ios.git
   cd casero.cu-ios
   open CaseroCU.xcodeproj
   ```

You need a recent Xcode and macOS.

## Branching

- `main` is always releasable.
- Branch from `main` using a descriptive prefix:
  - `feat/guest-list-paging`
  - `fix/session-expiry-redirect`
  - `docs/api-contract`

## Commits

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>(optional scope): <description>

[optional body]

[optional footer]
```

Common types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`,
`build`, `ci`, `chore`.

Examples:

```
feat(guests): parse .NET /Date(ms)/ timestamps as UTC
fix(auth): pin the casero.rem.cu certificate in the session challenge
docs: document the ViasComunicacion endpoint
```

Keep the subject line at 50 characters or fewer, in the imperative mood. Do not
add tool or AI attribution trailers.

## Pull requests

1. Make sure the project builds (`xcodebuild ... build`).
2. Run the tests and linter (`xcodebuild ... test`, `swiftlint`).
3. Fill in the [pull request template](.github/PULL_REQUEST_TEMPLATE.md).
4. Link any issue the PR closes (`Closes #123`).
5. Keep PRs focused — one logical change per PR.

## Reporting bugs and requesting features

- **iOS-specific bugs** → [open an issue](https://github.com/albertolicea00/casero.cu-ios/issues/new)
- **Core / cross-platform issues** (API changes, auth flow, etc.) → file in either repo
- Use the issue templates under [.github/ISSUE_TEMPLATE](.github/ISSUE_TEMPLATE)
- For anything touching the portal API, describe the request/response without including real credentials or guest data
