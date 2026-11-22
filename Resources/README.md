# Resources

`casero_rem_cu.cer` is the portal's public TLS certificate, pinned for
`casero.rem.cu`. What it is, why it is needed, its fingerprint and expiry, and how
to renew it are documented in [AGENTS.md](../ARCHITECTURE.md#pinned-tls-certificate).

`PrivacyInfo.xcprivacy` declares app-local UserDefaults and file timestamp usage.
The approved reasons are documented in Apple's [required reason API reference](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
The manifest does not assert a data-collection classification for the independent
government portal; review those disclosures before distribution.
