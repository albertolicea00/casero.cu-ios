# Public portal certificate

`casero_rem_cu.cer` is the public DER certificate pinned for `casero.rem.cu`.
It is included in Git and in generated app resources. It is not an Apple signing
certificate and contains no private key. All other `*.cer` files remain ignored.
Both URLSession and the embedded portal browser use the same pin, scoped to this
host. Other hosts receive default platform trust handling; browser navigation is
restricted to HTTPS on the portal host.

Current bundled SHA-256 fingerprint:

```text
CD:18:11:14:6B:37:3D:17:B0:0C:CB:44:B6:22:FA:EA:E1:F9:0A:59:46:98:5A:3E:1A:55:42:C6:BD:71:56:E2
```

The certificate validity interval ends on May 12, 2027. Confirm the current portal
certificate from a trusted connection inside Cuba before release or rotation.
A matching local file does not establish that the live server still presents it.
Never replace the pin automatically after a failed connection.

```bash
openssl s_client -connect casero.rem.cu:443 -servername casero.rem.cu </dev/null \
  | openssl x509 -outform der -out /tmp/casero_rem_cu.cer
openssl x509 -inform DER -in /tmp/casero_rem_cu.cer -noout -fingerprint -sha256 -dates
```

Verify the fingerprint through a trusted channel before replacing the bundled
file. A clean `xcodegen generate` includes it without manual Xcode changes.

`PrivacyInfo.xcprivacy` declares app-local UserDefaults and file timestamp usage.
The approved reasons are documented in Apple's [required reason API reference](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).
The manifest does not assert a data-collection classification for the independent
government portal; review those disclosures before distribution.
