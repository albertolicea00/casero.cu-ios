import Foundation
import Security

/// Pins the `casero.rem.cu` certificate. The portal serves a certificate that
/// fails validation against the device's public CA store. Trust is limited to
/// the bundled leaf certificate, then evaluated against the portal hostname
/// and normal certificate validity rules.
///
/// Bundle the DER certificate as `casero_rem_cu.cer` in the app resources. If it
/// is absent the pinner rejects every connection (fail closed).
enum CertificatePinner {

    private static let bundledName = "casero_rem_cu"

    /// Whether the pinned certificate ships in the app bundle. `CaseroClient`
    /// checks this before issuing any request so a missing certificate surfaces
    /// as `PortalError.certificateNotBundled` instead of a silent connection failure.
    static var isBundled: Bool { pinnedData != nil }

    private static let pinnedData: Data? = {
        guard let url = Bundle.main.url(forResource: bundledName, withExtension: "cer") else {
            return nil
        }
        return try? Data(contentsOf: url)
    }()

    /// Evaluates a server-trust challenge against the pinned certificate.
    static func evaluate(_ challenge: URLAuthenticationChallenge) -> (
        URLSession.AuthChallengeDisposition, URLCredential?
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        else {
            return (.performDefaultHandling, nil)
        }

        guard challenge.protectionSpace.host.lowercased() == "casero.rem.cu" else {
            return (.performDefaultHandling, nil)
        }

        guard let pinned = pinnedData else {
            // No bundled certificate — refuse rather than trust blindly.
            return (.cancelAuthenticationChallenge, nil)
        }

        guard let chain = SecTrustCopyCertificateChain(serverTrust) as? [SecCertificate],
            let leaf = chain.first
        else {
            return (.cancelAuthenticationChallenge, nil)
        }

        guard SecCertificateCopyData(leaf) as Data == pinned else {
            return (.cancelAuthenticationChallenge, nil)
        }

        // The portal's issuing CA is private and is not installed on user
        // devices. Trust this exact pinned leaf as the sole anchor, while still
        // checking its dates, server-auth usage, and hostname for this request.
        let policy = SecPolicyCreateSSL(true, challenge.protectionSpace.host as CFString)
        guard SecTrustSetPolicies(serverTrust, policy) == errSecSuccess,
            SecTrustSetAnchorCertificates(serverTrust, [leaf] as CFArray) == errSecSuccess,
            SecTrustSetAnchorCertificatesOnly(serverTrust, true) == errSecSuccess,
            SecTrustEvaluateWithError(serverTrust, nil)
        else {
            return (.cancelAuthenticationChallenge, nil)
        }
        return (.useCredential, URLCredential(trust: serverTrust))
    }
}
